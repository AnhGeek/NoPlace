import 'dart:typed_data';

import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../../../../data/local/region_pack.dart';

/// Feeds a [RegionPack] to the vector tile renderer.
///
/// This is the whole adapter between our storage format and the map library:
/// four members, because `VectorTileProvider` is a small interface and a pack
/// is already indexed by z/x/y. Replacing the renderer means rewriting this
/// file and nothing else.
class RegionPackTileProvider extends VectorTileProvider {
  RegionPackTileProvider(this._pack);

  final RegionPack _pack;

  @override
  int get minimumZoom => _pack.info.minZoom;

  @override
  int get maximumZoom => _pack.info.maxZoom;

  @override
  TileOffset get tileOffset => TileOffset.DEFAULT;

  @override
  TileProviderType get type => TileProviderType.vector;

  /// An empty tile is not an error.
  ///
  /// Packs are cut to a bounding box; the viewport is a rectangle that will
  /// routinely overhang it, and the sea has no features either way. Returning
  /// zero bytes renders as empty ground, which is exactly right — throwing
  /// would put a retry loop on the corners of every pan.
  static final Uint8List _empty = Uint8List(0);

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    try {
      final data = await _pack.tile(tile.z, tile.x, tile.y);
      return data ?? _empty;
    } on Object catch (error) {
      // A read failure mid-session — the file yanked by an OS cleanup, a
      // corrupt page — must not be retryable. The map keeps its fog and its
      // pins, and simply has no streets here.
      throw ProviderException(
        message: 'region pack read failed for $tile: $error',
        retryable: Retryable.none,
      );
    }
  }
}
