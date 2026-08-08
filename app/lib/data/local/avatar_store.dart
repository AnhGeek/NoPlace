import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/repositories/repositories.dart';
import 'document_channel.dart';

/// The picture on the profile.
///
/// Two steps that have to happen together, which is why they are one object:
/// the bytes are copied into the app's own storage, and the path to the copy is
/// remembered. Keeping the gallery's URI instead would be a picture that
/// vanishes the day the player tidies up their photos — and a permission we
/// would have to hold on to for it not to.
class AvatarStore {
  AvatarStore(this._preferences, [this._documents = const DocumentChannel()]);

  final PreferencesRepository _preferences;
  final DocumentChannel _documents;

  /// Where the copies live. Not the cache directory — the OS is free to empty
  /// that, and a profile picture that disappears when the phone is low on space
  /// is a bug nobody would be able to reproduce.
  static const String _folder = 'avatar';

  bool get isSupported => _documents.isSupported;

  /// Asks the player for a picture, keeps a copy and remembers it.
  ///
  /// Returns false when they backed out of the picker, which is an answer and
  /// not a failure — nothing is said on screen about it.
  Future<bool> pick() async {
    try {
      final bytes = await _documents.open(mimeType: 'image/*');
      if (bytes == null || bytes.isEmpty) return false;

      await _replaceWith(bytes);
      return true;
    } on Object catch (error) {
      // A picture that will not copy is worth a log and nothing else. The
      // player keeps whatever they had, and the tap that failed must not throw
      // out of a button handler.
      debugPrint('Avatar: the picture could not be saved ($error)');
      return false;
    }
  }

  Future<void> _replaceWith(Uint8List bytes) async {
    final directory = Directory(
      p.join((await getApplicationSupportDirectory()).path, _folder),
    );
    if (!directory.existsSync()) directory.createSync(recursive: true);

    // A new name every time, rather than overwriting one file. Flutter caches
    // decoded images by path, so writing new bytes to the same name shows the
    // player their *old* picture until the app restarts.
    final file = File(
      p.join(directory.path, '${DateTime.now().millisecondsSinceEpoch}.img'),
    );
    await file.writeAsBytes(bytes, flush: true);

    await _preferences.setAvatarPath(file.path);
    _sweep(directory, keep: file.path);
  }

  /// Removes the picture, leaving the placeholder.
  Future<void> clear() async {
    await _preferences.setAvatarPath(null);

    final directory = Directory(
      p.join((await getApplicationSupportDirectory()).path, _folder),
    );
    if (directory.existsSync()) _sweep(directory, keep: null);
  }

  /// Deletes every copy but the current one.
  ///
  /// Best-effort and never awaited by the caller: a file that will not delete
  /// costs a few kilobytes, and refusing to change the player's picture over it
  /// would be the worse trade.
  void _sweep(Directory directory, {required String? keep}) {
    try {
      for (final entity in directory.listSync()) {
        if (entity is File && entity.path != keep) entity.deleteSync();
      }
    } on Object catch (error) {
      debugPrint('Avatar: an old copy could not be removed ($error)');
    }
  }
}
