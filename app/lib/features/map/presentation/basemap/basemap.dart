import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../../../../data/repository_providers.dart';
import '../../../../domain/entities/basemap_info.dart';
import 'np_basemap_style.dart';
import 'region_pack_tile_provider.dart';

/// Everything [MapCanvas] needs to draw streets: where the tiles come from,
/// how they should look, and what the licence obliges us to say about them.
///
/// Bundled into one object so the canvas takes a single nullable parameter.
/// Null means "no pack", which is a supported state — the map is then the fog
/// and the player's own points, exactly as it was before there was a basemap.
class Basemap {
  const Basemap({
    required this.theme,
    required this.cityBorderTheme,
    required this.tileProviders,
    required this.info,
  });

  /// The map itself: ground, water, roads, labels. Drawn under the fog.
  final vtr.Theme theme;

  /// Just the city's edge, drawn *over* the fog — see
  /// [NpBasemapStyle.buildCityBorder].
  final vtr.Theme cityBorderTheme;

  final TileProviders tileProviders;
  final BasemapInfo info;
}

/// Built once per pack, not per frame: reading the style JSON into a theme
/// walks every layer, and the map rebuilds on every position fix.
final basemapProvider = Provider<Basemap?>((ref) {
  final packs = ref.watch(regionPackProvider);

  // While the next region's pack is opening, the value still carried here is
  // the *previous* region's — and that one has already been closed, because
  // closing it is what `regionPackProvider` does on the way out. Drawing with
  // it throws `database_closed` on every tile the new viewport asks for, and
  // those failures are deliberately not retryable, so the map stays blank for
  // the rest of the session. No basemap for the moment it takes to open the
  // new pack is the honest state, and it is the one the map already handles.
  if (packs.isLoading) return null;

  final pack = packs.value;
  if (pack == null) return null;

  // One provider, shared by both layers: the same pack, read twice per tile.
  final provider = RegionPackTileProvider(pack);

  return Basemap(
    theme: vtr.ThemeReader().read(NpBasemapStyle.build()),
    cityBorderTheme: vtr.ThemeReader().read(NpBasemapStyle.buildCityBorder()),
    tileProviders: TileProviders({NpBasemapStyle.sourceName: provider}),
    info: pack.info,
  );
});
