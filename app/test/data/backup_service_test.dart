import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/data/local/app_database.dart';
import 'package:noplace/data/local/backup_service.dart';
import 'package:noplace/data/local/sqlite_map_point_repository.dart';
import 'package:noplace/data/local/sqlite_preferences_repository.dart';
import 'package:noplace/data/local/sqlite_trail_repository.dart';
import 'package:noplace/domain/entities/geo_point.dart';
import 'package:noplace/domain/entities/map_point.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const benThanh = GeoPoint(10.7725, 106.6980);
  const taoDan = GeoPoint(10.76984, 106.69289);
  const testRegion = 'vn-hcmc';

  /// A whole device's worth of storage, wired the way the app wires it.
  ///
  /// Returned as a record rather than shared state so the two halves of a
  /// round-trip test — the phone that was lost and the phone being restored —
  /// can exist at the same time and cannot see each other's memory.
  ({
    Directory directory,
    AppDatabase database,
    SqliteTrailRepository trail,
    SqliteMapPointRepository mapPoints,
    SqlitePreferencesRepository preferences,
    BackupService backup,
  })
  makeDevice() {
    final directory = Directory.systemTemp.createTempSync('np_backup_test');
    final database = AppDatabase(directory: directory);
    final trail = SqliteTrailRepository(database, regionId: testRegion);
    final mapPoints = SqliteMapPointRepository(database);
    final preferences = SqlitePreferencesRepository(database);

    addTearDown(() async {
      await database.close();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    return (
      directory: directory,
      database: database,
      trail: trail,
      mapPoints: mapPoints,
      preferences: preferences,
      backup: BackupService(
        database: database,
        trail: trail,
        mapPoints: mapPoints,
        preferences: preferences,
      ),
    );
  }

  MapPoint point(String id) => MapPoint(
    id: id,
    kind: MapPointKind.user,
    location: benThanh,
    createdAt: DateTime(2026, 7, 31),
    label: 'Test $id',
    iconId: 'star',
  );

  test('a walk survives being moved to another phone', () async {
    final old = makeDevice();
    await old.trail.load();
    await old.mapPoints.load();
    await old.preferences.load();

    await old.trail.record(benThanh);
    await old.trail.record(taoDan);
    await old.mapPoints.add(point('p1'));
    await old.preferences.setNearbyRadiusMeters(5000);

    final file = await old.backup.export();

    final fresh = makeDevice();
    await fresh.trail.load();
    await fresh.mapPoints.load();
    await fresh.preferences.load();
    expect(fresh.trail.current.isEmpty, isTrue);

    final restored = await fresh.backup.import(file);

    expect(restored.trailPoints, 2);
    expect(restored.mapPoints, 1);
    expect(restored.regions, [testRegion]);

    // Not just in the database: on the streams the map is watching.
    expect(fresh.trail.current.contains(benThanh), isTrue);
    expect(fresh.trail.current.contains(taoDan), isTrue);
    expect(fresh.mapPoints.current.single.label, 'Test p1');
    expect(fresh.preferences.currentNearbyRadiusMeters, 5000);
  });

  test('the last metres of a walk are in the file, not still in memory', () async {
    final old = makeDevice();
    await old.trail.load();

    // Recorded and deliberately never flushed — the walk is still going. This
    // is what a backup taken at the end of one has to catch.
    await old.trail.record(benThanh);
    final file = await old.backup.export();

    final fresh = makeDevice();
    await fresh.trail.load();
    await fresh.mapPoints.load();
    await fresh.preferences.load();

    expect((await fresh.backup.import(file)).trailPoints, 1);
  });

  test('restoring adds to what is there rather than replacing it', () async {
    final old = makeDevice();
    await old.trail.load();
    await old.trail.record(benThanh);
    final file = await old.backup.export();

    final other = makeDevice();
    await other.trail.load();
    await other.mapPoints.load();
    await other.preferences.load();
    // Ground walked on this phone, after the backup was taken elsewhere.
    await other.trail.record(taoDan);

    await other.backup.import(file);

    expect(other.trail.current.contains(benThanh), isTrue);
    expect(other.trail.current.contains(taoDan), isTrue);
  });

  test('restoring the same file twice changes nothing the second time', () async {
    final device = makeDevice();
    await device.trail.load();
    await device.mapPoints.load();
    await device.preferences.load();
    await device.trail.record(benThanh);
    await device.mapPoints.add(point('p1'));

    final file = await device.backup.export();
    await device.backup.import(file);
    await device.backup.import(file);

    final db = await device.database.open();
    expect(await db.query('trail_points'), hasLength(1));
    expect(await db.query('map_points'), hasLength(1));
  });

  test('a backup can be read after being gunzipped by hand', () async {
    final old = makeDevice();
    await old.trail.load();
    await old.trail.record(benThanh);

    final unpacked = Uint8List.fromList(gzip.decode(await old.backup.export()));
    // Readable as text, which is half the promise of the format.
    expect(utf8.decode(unpacked), contains('"format":"noplace.backup"'));

    final fresh = makeDevice();
    await fresh.trail.load();
    await fresh.mapPoints.load();
    await fresh.preferences.load();
    await fresh.backup.import(unpacked);

    expect(fresh.trail.current.contains(benThanh), isTrue);
  });

  group('a file that is not a backup', () {
    test('is refused rather than half-applied', () async {
      final device = makeDevice();
      await device.trail.load();
      await device.mapPoints.load();
      await device.preferences.load();

      await expectLater(
        device.backup.import(Uint8List.fromList(utf8.encode('{"hello":1}'))),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.problem,
            'problem',
            BackupProblem.notABackup,
          ),
        ),
      );
    });

    test('is refused when it is not text at all', () async {
      final device = makeDevice();
      await expectLater(
        device.backup.import(Uint8List.fromList([0xC3, 0x28, 0xA0, 0xA1])),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('written by a newer build is refused, not guessed at', () async {
      final device = makeDevice();
      final future = jsonEncode({
        'format': BackupService.formatId,
        'version': BackupService.formatVersion + 1,
        'trail': <Object?>[],
      });

      await expectLater(
        device.backup.import(Uint8List.fromList(utf8.encode(future))),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.problem,
            'problem',
            BackupProblem.tooNew,
          ),
        ),
      );
    });
  });

  test('a corrupt row is skipped and the rest of the walk restored', () async {
    final old = makeDevice();
    await old.trail.load();
    await old.trail.record(benThanh);
    await old.trail.record(taoDan);

    final document =
        jsonDecode(utf8.decode(gzip.decode(await old.backup.export())))
            as Map<String, Object?>;
    (document['trail']! as List<Object?>).add(['not', 'a', 'row']);

    final fresh = makeDevice();
    await fresh.trail.load();
    await fresh.mapPoints.load();
    await fresh.preferences.load();

    final restored = await fresh.backup.import(
      Uint8List.fromList(utf8.encode(jsonEncode(document))),
    );

    expect(restored.trailPoints, 2);
    expect(fresh.trail.current.count, 2);
  });

  test('the file name sorts chronologically', () {
    final device = makeDevice();
    expect(
      device.backup.suggestedFileName(DateTime(2026, 8, 5)),
      'noplace-2026-08-05.noplace',
    );
  });

  test('counts what is on the device before anything is backed up', () async {
    final device = makeDevice();
    await device.trail.load();
    await device.mapPoints.load();
    await device.preferences.load();

    expect((await device.backup.currentContents()).isEmpty, isTrue);

    await device.trail.record(benThanh);
    await device.mapPoints.add(point('p1'));
    await device.trail.flush();

    final contents = await device.backup.currentContents();
    expect(contents.trailPoints, 1);
    expect(contents.mapPoints, 1);
    expect(contents.regions, [testRegion]);
  });
}
