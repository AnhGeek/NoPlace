import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/data/local/region_catalogue.dart';
import 'package:noplace/data/local/region_pack.dart';
import 'package:noplace/data/local/region_pack_store.dart';
import 'package:noplace/data/repository_providers.dart';
import 'package:noplace/features/map/presentation/basemap/basemap.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // The desktop VM needs the FFI factory; the SQL is the same the phone runs.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('np_pack_test');
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  /// Writes a minimal but honest MBTiles pack: the tables the spec requires,
  /// the metadata ours adds, and whatever tiles the test needs.
  Future<String> writePack({
    String name = 'test.mbtiles',
    Map<String, String> metadata = const {},
    List<(int z, int column, int row, List<int> data)> tiles = const [],
  }) async {
    final path = '${directory.path}/$name';
    final db = await databaseFactory.openDatabase(path);

    await db.execute('CREATE TABLE metadata (name TEXT, value TEXT)');
    await db.execute(
      'CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, '
      'tile_row INTEGER, tile_data BLOB)',
    );

    final values = {
      'name': 'Test region',
      'format': 'pbf',
      'bounds': '106.36,10.34,107.03,11.16',
      'minzoom': '12',
      'maxzoom': '15',
      'np:format_version': '1',
      'np:region_id': 'vn-test',
      'np:region_name': 'Test region',
      'np:attribution': '© OpenStreetMap contributors',
      ...metadata,
    };
    for (final entry in values.entries) {
      if (entry.value == _absent) continue;
      await db.insert('metadata', {'name': entry.key, 'value': entry.value});
    }

    for (final tile in tiles) {
      await db.insert('tiles', {
        'zoom_level': tile.$1,
        'tile_column': tile.$2,
        'tile_row': tile.$3,
        'tile_data': Uint8List.fromList(tile.$4),
      });
    }

    await db.close();
    return path;
  }

  group('tile addressing', () {
    // The classic MBTiles bug: MBTiles rows run bottom-up (TMS), the map asks
    // top-down (XYZ). Getting it wrong renders a vertically mirrored city,
    // which is easy to miss on a symmetric one — so this is checked at two
    // zooms, where the wrong answer differs by a different amount each time.
    test('flips the y axis between XYZ and TMS at two zoom levels', () async {
      final path = await writePack(
        tiles: [
          // z12: XYZ y=1000 lives at row (1<<12)-1-1000 = 3095.
          (12, 3300, 3095, [1, 1]),
          // z15: XYZ y=8000 lives at row (1<<15)-1-8000 = 24767.
          (15, 26400, 24767, [2, 2]),
        ],
      );

      final pack = await RegionPack.open(path);
      addTearDown(pack.close);

      expect(await pack.tile(12, 3300, 1000), [1, 1]);
      expect(await pack.tile(15, 26400, 8000), [2, 2]);

      // The un-flipped coordinate must miss, or a symmetric fixture could pass
      // a broken implementation.
      expect(await pack.tile(12, 3300, 3095), isNull);
    });

    test('a hole in the pack is null, not an exception', () async {
      final path = await writePack();
      final pack = await RegionPack.open(path);
      addTearDown(pack.close);

      expect(await pack.tile(12, 1, 1), isNull);
    });

    test('gunzips tiles that were stored compressed', () async {
      const payload = 'not really a vector tile, but it round-trips';
      final path = await writePack(
        tiles: [(12, 5, (1 << 12) - 1 - 5, gzip.encode(utf8.encode(payload)))],
      );

      final pack = await RegionPack.open(path);
      addTearDown(pack.close);

      expect(utf8.decode((await pack.tile(12, 5, 5))!), payload);
    });
  });

  group('metadata', () {
    test('reads the region, zoom range and bounds', () async {
      final path = await writePack();
      final pack = await RegionPack.open(path);
      addTearDown(pack.close);

      expect(pack.info.regionId, 'vn-test');
      expect(pack.info.minZoom, 12);
      expect(pack.info.maxZoom, 15);
      expect(pack.tileFormat, 'pbf');

      // bounds is minLon,minLat,maxLon,maxLat — lon first, which is the
      // opposite of every other coordinate in this app.
      expect(pack.info.southWest.latitude, 10.34);
      expect(pack.info.southWest.longitude, 106.36);
      expect(pack.info.northEast.latitude, 11.16);
      expect(pack.info.northEast.longitude, 107.03);
    });

    test('renders attribution verbatim, including an empty one', () async {
      final path = await writePack(metadata: {'np:attribution': ''});
      final pack = await RegionPack.open(path);
      addTearDown(pack.close);

      // Empty is a deliberate choice by whoever cooked the pack — a source
      // that needs no credit — and must not be replaced with a default.
      expect(pack.info.attribution, '');
    });
  });

  group('refusal', () {
    test('refuses a pack from a future format version', () async {
      final path = await writePack(metadata: {'np:format_version': '99'});

      await expectLater(
        RegionPack.open(path),
        throwsA(isA<RegionPackException>()),
      );
    });

    test('refuses a pack with no format version', () async {
      final path = await writePack(metadata: {'np:format_version': _absent});

      await expectLater(
        RegionPack.open(path),
        throwsA(isA<RegionPackException>()),
      );
    });

    test('refuses a pack with malformed bounds', () async {
      final path = await writePack(metadata: {'bounds': 'somewhere nice'});

      await expectLater(
        RegionPack.open(path),
        throwsA(isA<RegionPackException>()),
      );
    });

    test('refuses a file that is not a database at all', () async {
      final path = '${directory.path}/truncated.mbtiles';
      File(path).writeAsBytesSync([0, 1, 2, 3, 4, 5]);

      await expectLater(RegionPack.open(path), throwsA(isA<Object>()));
    });
  });

  group('store', () {
    test('prefers a downloaded pack over the bundled one', () async {
      Directory('${directory.path}/region_packs').createSync(recursive: true);

      // The store looks for `<id>.mbtiles` (downloaded) before
      // `<id>.bundled.mbtiles` (already extracted from the APK). Both are on
      // disk here, so the winner is decided by precedence and nothing else.
      await writePack(
        name: 'region_packs/vn-test.mbtiles',
        metadata: {'np:region_name': 'downloaded'},
      );
      await writePack(
        name: 'region_packs/vn-test.bundled.mbtiles',
        metadata: {'np:region_name': 'bundled'},
      );

      final store = RegionPackStore(directory: directory);
      addTearDown(store.dispose);

      final pack = await store.open(
        // There is no asset bundle in a plain Dart test, so extraction fails
        // and the store falls back to the copy already on disk — which is the
        // behaviour a phone needs anyway.
        const RegionPackSource(
          regionId: 'vn-test',
          name: 'Test',
          bundledAsset: 'assets/maps/vn-test.mbtiles',
        ),
      );
      addTearDown(() => pack?.close());

      expect(pack, isNotNull);
      expect(pack!.info.regionName, 'downloaded');
    });

    test('the bundled regions are the ones the release cooks', () {
      // The workflow cooks exactly the packs that claim a bundled asset. If a
      // region gains one here and .github/workflows/release.yml is not updated
      // with it, the APK ships a catalogue pointing at an asset that is not in
      // it — and the map silently falls back to no basemap on that ground.
      expect(
        [
          for (final region in RegionCatalogue.all)
            if (region.bundledAsset != null) region.regionId,
        ],
        ['vn-hcmc', 'vn-dongnai'],
      );
    });

    test('a corrupt pack costs the basemap, not the app', () async {
      Directory('${directory.path}/region_packs').createSync(recursive: true);
      File(
        '${directory.path}/region_packs/vn-test.mbtiles',
      ).writeAsBytesSync([9, 9, 9]);

      final store = RegionPackStore(directory: directory);
      addTearDown(store.dispose);

      expect(
        await store.open(
          const RegionPackSource(
            regionId: 'vn-test',
            name: 'Test',
            remoteUrl: 'https://example.invalid/vn-test.mbtiles',
          ),
        ),
        isNull,
      );
    });
  });

  group('the basemap while a region is switching', () {
    // The regression this exists for: crossing into Đồng Nai left the map
    // blank for the rest of the session. `regionPackProvider` closes the old
    // pack on the way out, but an `AsyncValue` being refreshed still carries
    // the old value — so the basemap was rebuilt around a closed database and
    // every tile the new viewport asked for threw `database_closed`, which is
    // deliberately not retryable.
    test('is null rather than a pack that has already been closed', () async {
      final path = await writePack(
        tiles: [
          (12, 1, 1, [1, 2, 3]),
        ],
      );
      final pack = await RegionPack.open(path);
      addTearDown(pack.close);

      final switching = StateProvider<bool>((ref) => false);
      final container = ProviderContainer(
        overrides: [
          regionPackProvider.overrideWith((ref) async {
            // The second region's pack, still opening. Riverpod hands the
            // previous one out underneath it.
            if (ref.watch(switching)) return Completer<RegionPack?>().future;
            return pack;
          }),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(basemapProvider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(regionPackProvider.future);
      expect(container.read(basemapProvider), isNotNull);

      container.read(switching.notifier).state = true;

      expect(
        container.read(regionPackProvider).value,
        isNotNull,
        reason: 'the stale pack is still in the AsyncValue — that is the trap',
      );
      expect(container.read(basemapProvider), isNull);
    });
  });
}

/// Sentinel for "leave this key out of the pack entirely", which is different
/// from writing an empty value.
const String _absent = '<absent>';
