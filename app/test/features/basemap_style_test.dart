import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/features/map/presentation/basemap/np_basemap_style.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

/// The style is built in Dart but consumed as MapLibre JSON, so a typo in a
/// paint property does not fail to compile — it fails silently, by producing a
/// theme with the layer quietly missing. These tests are the compile step the
/// language does not give us.
void main() {
  test('the ground style parses into layers', () {
    final theme = ThemeReader().read(NpBasemapStyle.build());
    expect(theme.layers, isNotEmpty);
  });

  test('every ground layer survives the reader', () {
    // `ThemeReader` drops any layer it cannot understand and logs a warning
    // nobody sees. A dropped layer is a missing road class on the map.
    final style = NpBasemapStyle.build();
    final declared = (style['layers']! as List).length;

    expect(ThemeReader().read(style).layers, hasLength(declared));
  });

  group('the city border', () {
    test('parses into exactly one layer', () {
      final theme = ThemeReader().read(NpBasemapStyle.buildCityBorder());
      expect(theme.layers, hasLength(1));
    });

    test('draws no background', () {
      // It is rendered *over* the fog. A background layer would paint the whole
      // tile and erase everything the player earned.
      final layers = NpBasemapStyle.buildCityBorder()['layers']! as List;

      expect(
        layers.map((layer) => (layer as Map)['type']),
        everyElement(isNot('background')),
      );
    });

    test('selects the province boundary and nothing else', () {
      // `region` is OpenStreetMap admin level 4, which in Vietnam is the
      // province — and Ho Chi Minh City is a province-level unit. Matching
      // `county` here would outline every district instead of the city.
      final layer =
          (NpBasemapStyle.buildCityBorder()['layers']! as List).single as Map;

      expect(layer['source-layer'], 'boundaries');
      expect(layer['filter'], ['in', 'kind', 'region']);
    });

    test('district edges stay on the ground layer, under the fog', () {
      final layers = NpBasemapStyle.build()['layers']! as List;
      final boundaries = layers
          .cast<Map<String, dynamic>>()
          .where((layer) => layer['source-layer'] == 'boundaries')
          .toList();

      expect(boundaries, hasLength(1));
      expect(boundaries.single['filter'], isNot(contains('region')));
    });
  });
}
