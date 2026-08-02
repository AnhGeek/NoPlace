import 'dart:io';
import 'dart:typed_data';

/// A reader for the PMTiles v3 archive format.
///
/// Written here rather than pulled from pub for one reason: the `pmtiles` CLI
/// converts MBTiles *to* PMTiles and not back, and every Dart PMTiles package
/// conflicts with the app's dependency graph. This is build-time code — it
/// never ships — so a hundred lines against a published spec is the cheap
/// answer.
///
/// Spec: https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md
class PmTilesArchive {
  PmTilesArchive._(this._bytes, this.header);

  final Uint8List _bytes;
  final PmTilesHeader header;

  static PmTilesArchive open(String path) {
    final bytes = File(path).readAsBytesSync();
    if (bytes.length < PmTilesHeader.lengthInBytes) {
      throw const FormatException('file is too short to be a PMTiles archive');
    }

    final magic = String.fromCharCodes(bytes.sublist(0, 7));
    if (magic != 'PMTiles') {
      throw FormatException('not a PMTiles archive (magic was "$magic")');
    }
    if (bytes[7] != 3) {
      throw FormatException('PMTiles v${bytes[7]} is not supported, only v3');
    }

    return PmTilesArchive._(bytes, PmTilesHeader._parse(bytes));
  }

  /// Every tile in the archive, walked in directory order.
  ///
  /// Yields the tile bytes exactly as stored — still compressed with
  /// [PmTilesHeader.tileCompression], which for our purposes is what MBTiles
  /// wants anyway.
  Iterable<PmTile> tiles() sync* {
    for (final entry in _directory(header.rootOffset, header.rootLength)) {
      if (entry.runLength == 0) {
        // A pointer to a leaf directory rather than a tile.
        final leaf = _directory(
          header.leafDirectoriesOffset + entry.offset,
          entry.length,
        );
        for (final leafEntry in leaf) {
          yield* _tilesFor(leafEntry);
        }
      } else {
        yield* _tilesFor(entry);
      }
    }
  }

  Iterable<PmTile> _tilesFor(_Entry entry) sync* {
    if (entry.runLength == 0) return;

    final start = header.tileDataOffset + entry.offset;
    final data = Uint8List.sublistView(_bytes, start, start + entry.length);

    // A run means one blob addressed by several consecutive tile ids — an
    // ocean tile shared by a whole row. Each still needs its own MBTiles row.
    for (var i = 0; i < entry.runLength; i++) {
      final zxy = tileIdToZxy(entry.tileId + i);
      yield PmTile(zxy.$1, zxy.$2, zxy.$3, data);
    }
  }

  List<_Entry> _directory(int offset, int length) {
    var bytes = Uint8List.sublistView(_bytes, offset, offset + length);
    if (header.internalCompression == _Compression.gzip) {
      bytes = Uint8List.fromList(gzip.decode(bytes));
    }

    final reader = _VarintReader(bytes);
    final count = reader.readVarint();

    final entries = List.generate(count, (_) => _Entry());

    // The four fields are stored as four columns, not as interleaved records.
    var tileId = 0;
    for (var i = 0; i < count; i++) {
      tileId += reader.readVarint();
      entries[i].tileId = tileId;
    }
    for (var i = 0; i < count; i++) {
      entries[i].runLength = reader.readVarint();
    }
    for (var i = 0; i < count; i++) {
      entries[i].length = reader.readVarint();
    }
    for (var i = 0; i < count; i++) {
      final value = reader.readVarint();
      // Zero means "immediately after the previous entry", which is how a
      // clustered archive avoids storing an offset per tile.
      entries[i].offset = value == 0
          ? entries[i - 1].offset + entries[i - 1].length
          : value - 1;
    }

    return entries;
  }
}

class PmTile {
  const PmTile(this.z, this.x, this.y, this.data);

  final int z;
  final int x;
  final int y;

  /// As stored in the archive: still compressed.
  final Uint8List data;
}

class PmTilesHeader {
  const PmTilesHeader({
    required this.rootOffset,
    required this.rootLength,
    required this.leafDirectoriesOffset,
    required this.tileDataOffset,
    required this.addressedTiles,
    required this.internalCompression,
    required this.tileCompression,
    required this.minZoom,
    required this.maxZoom,
  });

  static const int lengthInBytes = 127;

  final int rootOffset;
  final int rootLength;
  final int leafDirectoriesOffset;
  final int tileDataOffset;
  final int addressedTiles;
  final int internalCompression;
  final int tileCompression;
  final int minZoom;
  final int maxZoom;

  bool get tilesAreGzipped => tileCompression == _Compression.gzip;

  static PmTilesHeader _parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes, 0, lengthInBytes);
    int u64(int at) => data.getUint64(at, Endian.little);

    return PmTilesHeader(
      rootOffset: u64(8),
      rootLength: u64(16),
      leafDirectoriesOffset: u64(40),
      tileDataOffset: u64(56),
      addressedTiles: u64(72),
      internalCompression: data.getUint8(97),
      tileCompression: data.getUint8(98),
      minZoom: data.getUint8(100),
      maxZoom: data.getUint8(101),
    );
  }
}

abstract final class _Compression {
  static const int gzip = 2;
}

class _Entry {
  int tileId = 0;
  int offset = 0;
  int length = 0;
  int runLength = 0;
}

class _VarintReader {
  _VarintReader(this._bytes);

  final Uint8List _bytes;
  int _position = 0;

  int readVarint() {
    var result = 0;
    var shift = 0;
    while (true) {
      final byte = _bytes[_position++];
      result |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) return result;
      shift += 7;
    }
  }
}

/// PMTiles addresses tiles by their position on a Hilbert curve, so that tiles
/// near each other on the map are near each other in the file — which is what
/// lets `pmtiles extract` fetch a city in 44 HTTP requests.
///
/// This is the inverse: curve position back to z/x/y.
(int, int, int) tileIdToZxy(int tileId) {
  var accumulated = 0;

  for (var z = 0; z < 27; z++) {
    final tilesAtZoom = 1 << (z * 2);
    if (accumulated + tilesAtZoom > tileId) {
      return _positionToXy(z, tileId - accumulated);
    }
    accumulated += tilesAtZoom;
  }

  throw ArgumentError('tile id $tileId is beyond zoom 26');
}

(int, int, int) _positionToXy(int z, int position) {
  final n = 1 << z;
  var x = 0;
  var y = 0;
  var t = position;

  for (var s = 1; s < n; s *= 2) {
    final rx = 1 & (t ~/ 2);
    final ry = 1 & (t ^ rx);

    // Rotate the quadrant so the curve stays continuous across it.
    if (ry == 0) {
      if (rx == 1) {
        x = s - 1 - x;
        y = s - 1 - y;
      }
      final swap = x;
      x = y;
      y = swap;
    }

    x += s * rx;
    y += s * ry;
    t ~/= 4;
  }

  return (z, x, y);
}
