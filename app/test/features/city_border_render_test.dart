import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/data/local/region_pack.dart';
import 'package:noplace/features/map/presentation/basemap/np_basemap_style.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

/// Renders the city border from the real pack and asserts that pixels land.
///
/// The border is a city-scale feature: at the app's own zoom levels it is tens
/// of kilometres off screen, so it cannot be checked by looking at a phone
/// without pinching out by hand. This drives the same renderer the app does,
/// against the same bytes, and answers the only question that matters — does
/// anything actually get drawn.
///
/// Skipped when the pack is absent, because a pack is cooked rather than
/// committed and a fresh clone has none.
void main() {
  const packPath = 'assets/maps/vn-hcmc.mbtiles';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'the city border draws pixels over Ho Chi Minh City',
    () async {
      // Absolute: sqflite resolves a relative path against its own databases
      // directory, not the working directory.
      final pack = await RegionPack.open(File(packPath).absolute.path);
      addTearDown(pack.close);

      // z9 over the middle of the city. At this zoom one tile spans roughly
      // 78 km, so the province edge is inside it.
      const z = 9;
      const x = 407;
      const y = 240;

      final bytes = await pack.tile(z, x, y);
      expect(bytes, isNotNull, reason: 'the pack should hold this tile');

      final theme = ThemeReader().read(NpBasemapStyle.buildCityBorder());
      final tile = TileFactory(
        theme,
        const Logger.noop(),
      ).create(VectorTileReader().read(bytes!));

      final image = await ImageRenderer(theme: theme, scale: 2).render(
        TileSource(tileset: Tileset({NpBasemapStyle.sourceName: tile})),
        zoom: z.toDouble(),
      );

      final pixels = await image.toByteData();
      expect(pixels, isNotNull);

      // Count anything that is not fully transparent. The border style paints no
      // background, so every opaque pixel is border.
      var drawn = 0;
      for (var i = 3; i < pixels!.lengthInBytes; i += 4) {
        if (pixels.getUint8(i) != 0) drawn++;
      }

      // Save it so a human can look at the line rather than trust a number.
      final out = File(
        '${Directory.systemTemp.path}/noplace_city_border_z$z.png',
      );
      await out.writeAsBytes(await image.toPng());
      // ignore: avoid_print
      print('city border render: $drawn opaque pixels -> ${out.path}');

      expect(
        drawn,
        greaterThan(100),
        reason: 'the province boundary should cross this tile',
      );
    },
    skip: File(packPath).existsSync() ? false : 'no cooked pack in this tree',
  );
}
