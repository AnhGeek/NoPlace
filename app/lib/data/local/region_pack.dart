import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/basemap_info.dart';
import '../../domain/entities/geo_point.dart';

/// Thrown when a pack cannot be trusted. Always caught: a bad pack must cost
/// the player their basemap, never their app.
class RegionPackException implements Exception {
  const RegionPackException(this.message);

  final String message;

  @override
  String toString() => 'RegionPackException: $message';
}

/// One city's map, in one file.
///
/// A pack is a valid MBTiles archive with extra NoPlace metadata — see
/// docs/region-pack-format.md. MBTiles is itself SQLite, which is why this
/// class is forty lines of queries rather than a binary format reader: the app
/// already links `sqflite`, and any MBTiles tool opens a pack and shows the
/// map, so the pipeline stays inspectable at every step.
///
/// The tiles are vector (`format = pbf`), so the look of the map is decided at
/// runtime by the theme in `features/map`, not baked in when the pack is cooked.
class RegionPack {
  RegionPack._(this._db, this.info, this.tileFormat);

  final Database _db;

  /// Region identity, zoom range, bounds and the attribution the app is
  /// obliged to display.
  final BasemapInfo info;

  /// `pbf` for vector packs, `png` for raster ones.
  final String tileFormat;

  /// The format version of docs/region-pack-format.md this build understands.
  ///
  /// A pack declaring a *higher* version is refused rather than guessed at: a
  /// future pipeline may add a table this build would silently misread.
  static const int supportedFormatVersion = 1;

  static Future<RegionPack> open(String path) async {
    if (!File(path).existsSync()) {
      throw RegionPackException('no pack at $path');
    }

    // Read-only, and not the shared single instance: this database has nothing
    // to do with the player's own data in `noplace.db`, and must never be
    // written to by us.
    final db = await openReadOnlyDatabase(path);

    try {
      final metadata = await _readMetadata(db);

      final declared = int.tryParse(metadata['np:format_version'] ?? '');
      if (declared == null) {
        throw const RegionPackException('missing np:format_version');
      }
      if (declared > supportedFormatVersion) {
        throw RegionPackException(
          'pack format v$declared is newer than this build understands '
          '(v$supportedFormatVersion)',
        );
      }

      final bounds = _parseBounds(metadata['bounds']);

      return RegionPack._(
        db,
        BasemapInfo(
          regionId: metadata['np:region_id'] ?? 'unknown',
          regionName: metadata['np:region_name'] ?? metadata['name'] ?? '',
          // Absent is a mistake and we cannot tell whose, so credit the only
          // source a free basemap realistically has. An explicitly empty
          // string is honoured as written.
          attribution:
              metadata['np:attribution'] ?? '© OpenStreetMap contributors',
          minZoom: int.tryParse(metadata['minzoom'] ?? '') ?? 0,
          maxZoom: int.tryParse(metadata['maxzoom'] ?? '') ?? 14,
          southWest: bounds.$1,
          northEast: bounds.$2,
        ),
        metadata['format'] ?? 'pbf',
      );
    } on Object {
      await db.close();
      rethrow;
    }
  }

  static Future<Map<String, String>> _readMetadata(Database db) async {
    final rows = await db.query('metadata', columns: ['name', 'value']);
    return {
      for (final row in rows)
        (row['name'] as String? ?? ''): (row['value'] as String? ?? ''),
    };
  }

  /// `minLon,minLat,maxLon,maxLat` — the MBTiles spec's order, which is not the
  /// order anything else in this app uses.
  static (GeoPoint, GeoPoint) _parseBounds(String? raw) {
    final parts = (raw ?? '').split(',');
    if (parts.length != 4) {
      throw const RegionPackException('missing or malformed bounds');
    }
    final values = parts.map((p) => double.tryParse(p.trim())).toList();
    if (values.any((v) => v == null)) {
      throw RegionPackException('malformed bounds: $raw');
    }
    return (GeoPoint(values[1]!, values[0]!), GeoPoint(values[3]!, values[2]!));
  }

  /// The tile at slippy-map (XYZ) coordinates, or null where the pack has no
  /// tile — sea, or outside the cooked bbox.
  ///
  /// A hole is not an error. Packs are cut to a bounding box and the viewport
  /// is a rectangle on a sphere; asking for the corners is normal.
  Future<Uint8List?> tile(int z, int x, int y) async {
    // MBTiles stores rows bottom-up (TMS); the map asks top-down (XYZ). Getting
    // this wrong looks like a vertically mirrored map, which is easy to miss on
    // a symmetric city — hence the test at two zoom levels.
    final row = (1 << z) - 1 - y;

    final rows = await _db.query(
      'tiles',
      columns: ['tile_data'],
      where: 'zoom_level = ? AND tile_column = ? AND tile_row = ?',
      whereArgs: [z, x, row],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final data = rows.first['tile_data'];
    if (data is! Uint8List || data.isEmpty) return null;

    return _gunzipIfNeeded(data);
  }

  /// The MBTiles spec requires vector tiles to be gzipped, and tools disagree
  /// about whether they honoured it. Sniff the magic number rather than trust
  /// either answer.
  static Uint8List _gunzipIfNeeded(Uint8List data) {
    if (data.length < 2 || data[0] != 0x1f || data[1] != 0x8b) return data;
    return Uint8List.fromList(gzip.decode(data));
  }

  Future<void> close() => _db.close();
}
