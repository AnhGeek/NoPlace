import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/geo_point.dart';
import 'region_pack.dart';

/// The ground a region claims, as a rectangle in degrees.
///
/// **Not the same thing as the tiles the pack holds.** A pack is cooked from a
/// generous bounding box that spills over the border, so its neighbour's
/// streets keep drawing while the player walks towards them. This is the
/// narrower question of *whose map to open when somebody is standing here*, and
/// the answer has to be exactly one region — so these rectangles are trimmed
/// not to overlap where the cooked boxes do.
@immutable
class RegionBounds {
  const RegionBounds({
    required this.minLatitude,
    required this.minLongitude,
    required this.maxLatitude,
    required this.maxLongitude,
  });

  final double minLatitude;
  final double minLongitude;
  final double maxLatitude;
  final double maxLongitude;

  bool contains(GeoPoint point) =>
      point.latitude >= minLatitude &&
      point.latitude <= maxLatitude &&
      point.longitude >= minLongitude &&
      point.longitude <= maxLongitude;

  GeoPoint get centre => GeoPoint(
    (minLatitude + maxLatitude) / 2,
    (minLongitude + maxLongitude) / 2,
  );
}

/// Where a region's map may be found, in the order the store will try.
///
/// The remote is a plain HTTPS URL and nothing more. That is the point: a pack
/// is a static file, so it can sit on Cloudflare R2, S3, a CDN or a directory
/// on a web server without this app knowing the difference. No vendor SDK, no
/// credentials, no lock-in.
@immutable
class RegionPackSource {
  const RegionPackSource({
    required this.regionId,
    this.bounds,
    this.bundledAsset,
    this.remoteUrl,
  }) : assert(
         bundledAsset != null || remoteUrl != null,
         'a region needs at least one source',
       );

  final String regionId;

  /// The ground this region answers for, or null when it is not a candidate
  /// for position-based resolution.
  final RegionBounds? bounds;

  /// A pack shipped inside the app, e.g. `assets/maps/vn-hcmc.mbtiles`.
  /// Always available, never stale-proof — it is whatever was current when the
  /// build was cut.
  final String? bundledAsset;

  /// Where a newer pack can be fetched. Any HTTPS object store.
  final String? remoteUrl;
}

/// Decides which copy of a region's map the app actually opens.
///
/// Precedence, highest first:
///
///  1. a pack downloaded to this device — it is by definition newer than the
///     one in the APK, because we only download when it is;
///  2. the pack bundled in the app — copied out to a file once, because SQLite
///     needs a path and an asset is not one;
///  3. nothing, and the map draws without a basemap rather than failing.
///
/// Downloading never happens on the path that opens the map. A player walking
/// through a dead zone gets the bundled pack immediately; a new one, if any,
/// arrives in the background and is picked up the *next* time the region loads.
/// A pack must never be swapped underneath a live map.
class RegionPackStore {
  RegionPackStore({Directory? directory, http.Client? client})
    : _overrideDirectory = directory,
      _client = client ?? http.Client();

  final Directory? _overrideDirectory;
  final http.Client _client;

  static const String _directoryName = 'region_packs';

  /// Opens the best available pack for [source], or null if there is none.
  ///
  /// Never throws. A corrupt pack, a pack from a future format version and a
  /// missing pack all end the same way: no basemap, and a line in the log.
  Future<RegionPack?> open(RegionPackSource source) async {
    for (final candidate in await _candidates(source)) {
      try {
        return await RegionPack.open(candidate);
      } on Object catch (error) {
        debugPrint('Region pack: $candidate unusable ($error)');
      }
    }
    return null;
  }

  Future<List<String>> _candidates(RegionPackSource source) async {
    final directory = await _packDirectory();
    final candidates = <String>[];

    final downloaded = p.join(directory.path, '${source.regionId}.mbtiles');
    if (File(downloaded).existsSync()) candidates.add(downloaded);

    final asset = source.bundledAsset;
    if (asset != null) {
      final extracted = await _extractAsset(asset, directory, source.regionId);
      if (extracted != null) candidates.add(extracted);
    }

    return candidates;
  }

  /// Copies a bundled pack out of the APK once, so SQLite has a path to open.
  ///
  /// Re-copied whenever the asset's size differs from the extracted file's,
  /// which is what makes an app update ship a new bundled map instead of
  /// leaving the first-run copy in place forever.
  Future<String?> _extractAsset(
    String asset,
    Directory directory,
    String regionId,
  ) async {
    final destination = File(
      p.join(directory.path, '$regionId.bundled.mbtiles'),
    );

    try {
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      if (destination.existsSync() &&
          destination.lengthSync() == bytes.length) {
        return destination.path;
      }

      // Same .tmp-then-rename as the trail store: a kill mid-copy must leave
      // the previous good file rather than a truncated one that SQLite would
      // then refuse.
      final temporary = File('${destination.path}.tmp');
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(destination.path);
      return destination.path;
    } on Object catch (error) {
      debugPrint('Region pack: could not extract $asset ($error)');
      // An earlier run may already have copied it out. A failure to read the
      // bundle now is no reason to throw away a good copy we already have.
      return destination.existsSync() ? destination.path : null;
    }
  }

  /// Fetches [source]'s remote pack into place, replacing any earlier download.
  ///
  /// Returns true when a new pack landed. Call it from the background; the
  /// result is visible the next time [open] runs.
  Future<bool> download(RegionPackSource source) async {
    final url = source.remoteUrl;
    if (url == null) return false;

    final directory = await _packDirectory();
    final destination = File(
      p.join(directory.path, '${source.regionId}.mbtiles'),
    );
    final temporary = File('${destination.path}.tmp');

    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint('Region pack: $url returned ${response.statusCode}');
        return false;
      }

      await temporary.writeAsBytes(response.bodyBytes, flush: true);

      // Prove it opens *before* it becomes the file the app will trust on next
      // launch. Downloading a corrupt pack over a working one would otherwise
      // break the map until the next release.
      final probe = await RegionPack.open(temporary.path);
      await probe.close();

      await temporary.rename(destination.path);
      return true;
    } on Object catch (error) {
      debugPrint('Region pack: download from $url failed ($error)');
      if (temporary.existsSync()) {
        try {
          temporary.deleteSync();
        } on Object catch (_) {
          // Best effort; a stray .tmp costs disk, not correctness.
        }
      }
      return false;
    }
  }

  Future<Directory> _packDirectory() async {
    final base = _overrideDirectory ?? await getApplicationSupportDirectory();
    final directory = Directory(p.join(base.path, _directoryName));
    if (!directory.existsSync()) directory.createSync(recursive: true);
    return directory;
  }

  void dispose() => _client.close();
}
