import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/async/replay_subject.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/rules/exploration_rules.dart';

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
/// See docs/adr/0009-real-location.md.
class GeolocatorLocationRepository implements LocationRepository {
  final ReplaySubject<LocationAvailability> _availability = ReplaySubject(
    LocationAvailability.unknown,
  );

  final StreamController<GeoPoint> _positions =
      StreamController<GeoPoint>.broadcast();

  StreamSubscription<Position>? _subscription;

  @override
  Stream<GeoPoint> watchPosition() => _positions.stream;

  @override
  Stream<LocationAvailability> watchAvailability() => _availability.stream;

  LocationAvailability get availability => _availability.value;

  @override
  Future<LocationAvailability> start() async {
    if (_subscription != null) return _availability.value;

    final state = await _resolvePermission();
    _availability.value = state;
    if (state != LocationAvailability.ready) return state;

    _subscription = Geolocator.getPositionStream(
      locationSettings: _settings(),
    ).listen(
      (position) => _positions.add(
        GeoPoint(position.latitude, position.longitude),
      ),
      onError: (Object error) {
        // A stream that dies mid-walk must leave the app in a state the player
        // can act on, not a silent one where the fog simply stops opening.
        debugPrint('Location: stream failed ($error)');
        unawaited(_recheck());
      },
      cancelOnError: false,
    );

    return state;
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
      LocationPermission.unableToDetermine => LocationAvailability.deniedForever,
      LocationPermission.denied => LocationAvailability.denied,
    };
  }

  /// Re-reads the service and permission state without prompting.
  ///
  /// For coming back from Settings: the player may have fixed the problem, and
  /// the screen should say so without them having to guess.
  Future<LocationAvailability> refresh() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _availability.value = LocationAvailability.serviceDisabled;
      return _availability.value;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      // Granted while we were away: start for real rather than just reporting.
      if (_subscription == null) return start();
      _availability.value = LocationAvailability.ready;
    } else if (permission == LocationPermission.deniedForever) {
      _availability.value = LocationAvailability.deniedForever;
    } else {
      _availability.value = LocationAvailability.denied;
    }
    return _availability.value;
  }

  Future<void> _recheck() async {
    await _subscription?.cancel();
    _subscription = null;
    await refresh();
  }

  LocationSettings _settings() {
    // The distance filter is the same number the trail records at, so the OS
    // does the throttling for us and we are not woken for movement we would
    // immediately discard.
    final distanceFilter = ExplorationRules
        .defaultRecordingPrecisionMeters
        .round();

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
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
  }
}
