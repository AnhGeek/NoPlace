import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/async/replay_subject.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/rules/exploration_rules.dart';
import 'background_tracking_channel.dart';

/// The device's GPS, behind the domain's [LocationRepository].
///
/// ## Why a foreground service and not background location
///
/// The product is "walking uncovers the map", and people walk with the phone in
/// a pocket and the screen off. On Android that needs the process to keep
/// receiving fixes while it is not visible, and there are two ways to get it:
///
/// * **`ACCESS_BACKGROUND_LOCATION`** — needs a Play Console declaration and a
///   policy review, and is routinely refused unless the core feature is
///   impossible without it. It exists for apps that track with no UI at all.
/// * **A foreground service typed `location`**, started while the app is
///   visible — keeps receiving fixes with only while-in-use permission, and
///   shows the player a persistent notification saying so.
///
/// We take the second. The player opens NoPlace before they walk, so the
/// service always starts in the foreground, and the permission we ask for is
/// the one people actually grant. The notification is not a cost to work around
/// either: an app quietly logging your position with nothing on screen is
/// exactly what the notification exists to prevent.
///
/// ## What keeps it alive once the screen goes off
///
/// The service is necessary and not sufficient. Two things outside `geolocator`
/// decide whether it survives a walk, and both are handled here:
///
/// * **Its notification must be postable.** From Android 13 that is a runtime
///   permission, asked for alongside location. A foreground service running
///   unannounced is the first one the system reclaims.
/// * **The process must not be dozed.** Doze and the OEM battery managers
///   freeze an unexempted app minutes after the screen goes off. That is not a
///   dropped fix, it is a stopped isolate — the exact shape of "the fog stopped
///   recording in my pocket". [batteryOptimised] reports it so the map can ask.
///
/// It also means a stream error while backgrounded must **not** be answered by
/// cancelling and re-subscribing: cancelling stops the foreground service, and
/// from Android 12 a backgrounded app is not allowed to start one again. The
/// restart waits for the app to be visible. See docs/adr/0009-real-location.md.
class GeolocatorLocationRepository implements LocationRepository {
  /// [platform] is injected so tests can drive the Android-only calls without
  /// a method channel. `this._platform` is not an option: a named parameter
  /// cannot start with an underscore, and the field has to stay private.
  GeolocatorLocationRepository({
    BackgroundTrackingChannel platform = const BackgroundTrackingChannel(),
    // ignore: prefer_initializing_formals
  }) : _platform = platform;

  final BackgroundTrackingChannel _platform;

  final ReplaySubject<LocationAvailability> _availability = ReplaySubject(
    LocationAvailability.unknown,
  );

  /// Whether the system may still doze this process, and so cut a walk short.
  /// Starts false: until we have asked, there is nothing to tell the player.
  final ReplaySubject<bool> _batteryOptimised = ReplaySubject(false);

  final StreamController<GeoPoint> _positions =
      StreamController<GeoPoint>.broadcast();

  StreamSubscription<Position>? _subscription;

  /// Set when the stream failed while the app was not visible. The repair —
  /// tearing the subscription down and starting it again — restarts the
  /// foreground service, which only the foreground is allowed to do.
  bool _restartWhenVisible = false;

  @override
  Stream<GeoPoint> watchPosition() => _positions.stream;

  @override
  Stream<LocationAvailability> watchAvailability() => _availability.stream;

  LocationAvailability get availability => _availability.value;

  /// Whether the OS is still free to freeze the process mid-walk.
  Stream<bool> watchBatteryOptimised() => _batteryOptimised.stream;

  /// True only while the app is actually on screen. Null — before the first
  /// lifecycle event — counts as foreground, because that is start-up.
  bool get _visible {
    final state = SchedulerBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  @override
  Future<LocationAvailability> start() async {
    if (_subscription != null) return _availability.value;

    final state = await _resolvePermission();
    _availability.value = state;
    if (state != LocationAvailability.ready) return state;

    // Before subscribing, not after: the service posts its notification the
    // moment the stream starts, and a notification refused at that point is one
    // Android never shows for the rest of the walk.
    await _platform.ensureNotificationPermission();
    unawaited(refreshBatteryOptimised());

    // Also before subscribing, and for the same reason in reverse: whatever the
    // stream produces must be free to land on top of this and correct it.
    await _emitLastKnown();

    _subscription = Geolocator.getPositionStream(locationSettings: _settings())
        .listen(
          (position) =>
              _positions.add(GeoPoint(position.latitude, position.longitude)),
          onError: _onStreamError,
          cancelOnError: false,
        );
    _restartWhenVisible = false;

    return state;
  }

  /// Pushes out the fix the OS already had, if it kept one.
  ///
  /// A cold GPS start is tens of seconds, and until the first fix lands the app
  /// has nothing to show but the seeded city centre — so it opens claiming the
  /// player is somewhere they have never been. The last known position is
  /// usually seconds old and always the right neighbourhood, which is the whole
  /// question the first screen has to answer.
  ///
  /// Stale by definition, and that is fine: everything downstream treats it as
  /// an ordinary fix, and the first real one replaces it. What it must not do is
  /// arrive *after* a real fix, which is why [start] awaits it before
  /// subscribing.
  Future<void> _emitLastKnown() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null || _positions.isClosed) return;
      _positions.add(GeoPoint(position.latitude, position.longitude));
    } on Object catch (error) {
      // Never kept one, or the platform refused to say. Either way the stream
      // is still coming, so this is a missed shortcut and not a failure.
      debugPrint('Location: no last known position ($error)');
    }
  }

  /// A stream that dies mid-walk must leave the app in a state the player can
  /// act on, not a silent one where the fog simply stops opening.
  ///
  /// What "act on" means depends on whether anyone is looking. On screen, we
  /// re-check and re-subscribe. In a pocket, we deliberately do nothing but
  /// remember: `cancelOnError` is false, so the stream may well recover on its
  /// own, and cancelling it to try again would stop the foreground service that
  /// a backgrounded app is not permitted to start back up.
  void _onStreamError(Object error) {
    debugPrint('Location: stream failed ($error)');
    if (!_visible) {
      _restartWhenVisible = true;
      return;
    }
    unawaited(_recheck());
  }

  Future<LocationAvailability> _resolvePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAvailability.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationAvailability.ready,
      LocationPermission.deniedForever ||
      LocationPermission.unableToDetermine =>
        LocationAvailability.deniedForever,
      LocationPermission.denied => LocationAvailability.denied,
    };
  }

  /// Re-reads the service and permission state without prompting.
  ///
  /// For coming back from Settings: the player may have fixed the problem, and
  /// the screen should say so without them having to guess. Also where a walk
  /// that failed in a pocket gets repaired, now that we are allowed to.
  Future<LocationAvailability> refresh() async {
    unawaited(refreshBatteryOptimised());

    if (!await Geolocator.isLocationServiceEnabled()) {
      _availability.value = LocationAvailability.serviceDisabled;
      return _availability.value;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      // Granted while we were away: start for real rather than just reporting.
      if (_subscription == null) return start();
      if (_restartWhenVisible) return _recheck();
      _availability.value = LocationAvailability.ready;
    } else if (permission == LocationPermission.deniedForever) {
      _availability.value = LocationAvailability.deniedForever;
    } else {
      _availability.value = LocationAvailability.denied;
    }
    return _availability.value;
  }

  /// Re-reads whether the process can still be frozen. Cheap, and worth doing
  /// on every resume: the player may have just answered the prompt.
  Future<bool> refreshBatteryOptimised() async {
    final optimised = await _platform.isBatteryOptimised();
    _batteryOptimised.value = optimised;
    return optimised;
  }

  /// Sends the player to the exemption prompt. They answer it, not us — the
  /// result shows up on the next [refreshBatteryOptimised].
  Future<void> requestBatteryExemption() =>
      _platform.requestBatteryExemption();

  Future<LocationAvailability> _recheck() async {
    _restartWhenVisible = false;
    await _subscription?.cancel();
    _subscription = null;
    return refresh();
  }

  LocationSettings _settings() {
    // The distance filter is the same number the trail records at, so the OS
    // does the throttling for us and we are not woken for movement we would
    // immediately discard.
    final distanceFilter = ExplorationRules.defaultRecordingPrecisionMeters
        .round();

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        // An explicit cadence, rather than whatever the fused provider decides
        // it can batch. Left unset, a screen-off device is free to deliver a
        // walk's worth of fixes in one late burst, and a burst that arrives
        // after the process was frozen never arrives at all.
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'NoPlace is uncovering the map',
          notificationText: 'Recording the ground you walk.',
          // The walk is the product; letting the CPU sleep through it would
          // mean coming back to a trail with holes in it.
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        // iOS's equivalent of the Android foreground service: keep delivering
        // while backgrounded, and show the blue status bar indicator so the
        // player can see it is happening.
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
      );
    }

    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );
  }

  @override
  Future<void> stop() async {
    _restartWhenVisible = false;
    await _subscription?.cancel();
    _subscription = null;
  }

  @override
  Future<void> openSettingsFor(LocationAvailability problem) async {
    switch (problem) {
      case LocationAvailability.serviceDisabled:
        await Geolocator.openLocationSettings();
      case LocationAvailability.deniedForever:
      case LocationAvailability.denied:
        await Geolocator.openAppSettings();
      case LocationAvailability.ready:
      case LocationAvailability.unknown:
        break;
    }
  }

  Future<void> dispose() async {
    await stop();
    await _positions.close();
    await _availability.close();
    await _batteryOptimised.close();
  }
}
