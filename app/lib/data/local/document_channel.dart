import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The system's save and open dialogs, for getting a file out of the app and
/// back into it. See `MainActivity.kt` for the Android side.
///
/// Two calls on the channel that is already there rather than a file-picking
/// dependency: the packages that do this pin a `win32` major the rest of the
/// app cannot use, and the one build that resolves does not compile under this
/// project's Android Gradle Plugin. See
/// docs/adr/0010-backup-and-restore.md.
///
/// Android only, and honest about it: [isSupported] is what the screen asks
/// before offering a button nothing is behind.
class DocumentChannel {
  const DocumentChannel();

  static const MethodChannel _channel = MethodChannel(
    'site.lya3hc.noplace/background_tracking',
  );

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Asks the player where to put [bytes], then writes them there.
  ///
  /// Returns false when they backed out of the dialog — an answer, not a
  /// failure, and nothing should be said about it on screen. Throws
  /// [PlatformException] if the write itself failed.
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    if (!isSupported) return false;

    final saved = await _channel.invokeMethod<bool>('saveDocument', {
      'fileName': fileName,
      'mimeType': mimeType,
      'bytes': bytes,
    });
    return saved ?? false;
  }

  /// Asks the player for a file and reads it.
  ///
  /// Null when they backed out. Throws [PlatformException] if it could not be
  /// read.
  ///
  /// [mimeType] is what the picker offers. The default shows everything, which
  /// is right for a backup — its extension has no registered type, so anything
  /// narrower greys out the only file worth picking. A caller that genuinely
  /// wants one kind of file, like the avatar picker asking for `image/*`, says
  /// so.
  Future<Uint8List?> open({String mimeType = '*/*'}) async {
    if (!isSupported) return null;
    return _channel.invokeMethod<Uint8List>('openDocument', {
      'mimeType': mimeType,
    });
  }
}
