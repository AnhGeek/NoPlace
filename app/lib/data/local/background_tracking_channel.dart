import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Android-only pieces that keep recording alive while NoPlace is not on
/// screen. See `MainActivity.kt` for why each one exists.
///
/// Every call is a no-op that answers "nothing to do" off Android, so callers
/// never have to branch on the platform.
class BackgroundTrackingChannel {
  const BackgroundTrackingChannel();

  static const MethodChannel _channel = MethodChannel(
    'site.lya3hc.noplace/background_tracking',
  );

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Makes sure the foreground service's notification can be posted.
  ///
  /// Returns whether it can. Refusing is not fatal — the service still starts —
  /// but it is worth knowing, because a suppressed notification is the state in
  /// which Android is most willing to reclaim the service.
  Future<bool> ensureNotificationPermission() async {
    if (!_supported) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'ensureNotificationPermission',
          ) ??
          true;
    } on PlatformException catch (error) {
      debugPrint('Background tracking: notification permission ($error)');
      return true;
    }
  }

  /// Whether the system may still doze this process — the thing that puts holes
  /// in a pocketed walk.
  Future<bool> isBatteryOptimised() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isBatteryOptimised') ?? false;
    } on PlatformException catch (error) {
      debugPrint('Background tracking: battery state ($error)');
      return false;
    }
  }

  /// Opens the exemption prompt. The player answers it, not us; poll
  /// [isBatteryOptimised] again on resume to find out what they said.
  Future<void> requestBatteryExemption() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('requestBatteryExemption');
    } on PlatformException catch (error) {
      debugPrint('Background tracking: battery exemption ($error)');
    }
  }
}
