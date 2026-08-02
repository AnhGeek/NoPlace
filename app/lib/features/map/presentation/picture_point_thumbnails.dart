import 'dart:io';

import 'package:flutter/widgets.dart';

/// Turns the photo attached to a picture point into a pin-sized image.
///
/// **This is the seam for a feature that does not exist yet.** Taking a photo
/// and attaching it to a place is not built; when it is, it writes a file and
/// stores the path on the [MapPoint], and everything below already works.
///
/// The contract it exists to hold: the map must never decode a full-resolution
/// camera photo while scrolling. Each image is decoded once, at the size the pin
/// actually draws, and cached for the life of the app. Fifty photo points on
/// screen must cost fifty small textures, not fifty 12-megapixel bitmaps.
class PicturePointThumbnails {
  PicturePointThumbnails({this.decodeSize = 96});

  /// Edge length, in pixels, that a thumbnail is decoded at. Twice the pin's
  /// logical size, so it stays sharp on a 2×/3× screen without paying for the
  /// original.
  final int decodeSize;

  final Map<String, ImageProvider<Object>> _cache = {};

  /// Returns a provider for [path], or `null` when the file is missing.
  ///
  /// Missing is a normal state, not an error: a photo can be deleted from the
  /// gallery long after its point was dropped. The caller falls back to the
  /// icon.
  ImageProvider<Object>? thumbnailFor(String? path) {
    if (path == null || path.isEmpty) return null;

    final cached = _cache[path];
    if (cached != null) return cached;

    final file = File(path);
    if (!file.existsSync()) {
      debugPrint('Picture point: image missing at $path');
      return null;
    }

    return _cache[path] = ResizeImage(
      FileImage(file),
      width: decodeSize,
      height: decodeSize,
      policy: ResizeImagePolicy.fit,
    );
  }

  /// Drops decoded thumbnails. Call when the picture layer is hidden for a
  /// while, or on a memory-pressure warning.
  void evict() => _cache.clear();
}
