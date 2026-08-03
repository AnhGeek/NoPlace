import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noplace/data/local/background_tracking_channel.dart';
import 'package:noplace/data/local/geolocator_location_repository.dart';
import 'package:noplace/domain/repositories/repositories.dart';

/// A walk happens in a pocket, so the interesting cases are all the ones nobody
/// is looking at. These pin the rule that makes them survivable: a stream that
/// fails while the app is hidden must not be torn down and restarted, because
/// cancelling stops the location foreground service and Android 12+ refuses to
/// let a backgrounded app start one again.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeGeolocator geolocator;
  late GeolocatorLocationRepository repository;

  setUp(() {
    geolocator = _FakeGeolocator();
    GeolocatorPlatform.instance = geolocator;
    repository = GeolocatorLocationRepository(platform: const _NoPlatformCalls());
  });

  tearDown(() async {
    await repository.dispose();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  test('a fix reaches the position stream', () async {
    expect(await repository.start(), LocationAvailability.ready);

    final fix = repository.watchPosition().first;
    geolocator.emit(10.7725, 106.6980);

    expect((await fix).latitude, closeTo(10.7725, 1e-9));
  });

  test('a stream error in the background keeps the service running', () async {
    await repository.start();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    geolocator.fail('GPS hiccup');
    await pumpEventQueue();

    // The subscription is what owns the foreground service. Still ours.
    expect(geolocator.cancelled, isFalse);
    expect(geolocator.streamCount, 1);
  });

  test('the next resume repairs the stream that failed', () async {
    await repository.start();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    geolocator.fail('GPS hiccup');
    await pumpEventQueue();

    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(await repository.refresh(), LocationAvailability.ready);

    // Now that we are visible we are allowed to start a service again, so the
    // old subscription goes and a fresh one takes its place.
    expect(geolocator.cancelled, isTrue);
    expect(geolocator.streamCount, 2);
  });

  test('a stream error in the foreground is repaired immediately', () async {
    await repository.start();

    geolocator.fail('GPS hiccup');
    await pumpEventQueue();

    expect(geolocator.streamCount, 2);
  });

  test('a resume with nothing wrong does not churn the service', () async {
    await repository.start();

    expect(await repository.refresh(), LocationAvailability.ready);
    expect(geolocator.cancelled, isFalse);
    expect(geolocator.streamCount, 1);
  });
}

/// Just enough of the plugin to drive the cases above: permission granted,
/// service on, and a position stream we can fail on demand.
class _FakeGeolocator extends GeolocatorPlatform {
  _FakeGeolocator() : super();

  int streamCount = 0;
  bool cancelled = false;
  StreamController<Position>? _controller;

  void emit(double latitude, double longitude) {
    _controller?.add(
      Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
  }

  void fail(String message) => _controller?.addError(message);

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streamCount++;
    unawaited(_controller?.close());
    // Deliberately outlives this call: the test drives it afterwards, and
    // whoever replaces it closes it.
    // ignore: close_sinks
    final controller = StreamController<Position>.broadcast(
      onCancel: () => cancelled = true,
    );
    _controller = controller;
    return controller.stream;
  }
}

/// The Android-only calls, answered without a method channel.
class _NoPlatformCalls implements BackgroundTrackingChannel {
  const _NoPlatformCalls();

  @override
  Future<bool> ensureNotificationPermission() async => true;

  @override
  Future<bool> isBatteryOptimised() async => false;

  @override
  Future<void> requestBatteryExemption() async {}
}
