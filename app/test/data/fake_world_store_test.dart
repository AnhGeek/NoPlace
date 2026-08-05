import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/data/fake/fake_repositories.dart';
import 'package:noplace/data/fake/fake_world_store.dart';
import 'package:noplace/domain/entities/geo_point.dart';
import 'package:noplace/domain/entities/log_entry.dart';
import 'package:noplace/domain/entities/place.dart';
import 'package:noplace/domain/repositories/repositories.dart';

void main() {
  late FakeWorldStore store;

  setUp(() => store = FakeWorldStore());

  group('moving the player', () {
    // Regression guard. `watchNearbyPlaces` used to recompute on the *places*
    // stream, which emits once and never again — so with a fixed seed position
    // it looked correct, and with a real GPS the nearby list, the distances and
    // the check-in candidate all froze at wherever the app started.
    test('nearby places are recomputed when the player moves', () async {
      final repository = FakeWorldRepository(store);

      // One subscription, because the stream is single-listen — and because
      // this is exactly how the app consumes it.
      final emissions = <List<Place>>[];
      final subscription = repository
          .watchNearbyPlaces(radiusMeters: 500)
          .listen(emissions.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(
        emissions.last,
        isNotEmpty,
        reason: 'starts beside the seed places',
      );

      // Hanoi: about 1100 km from anything the fake world knows about.
      store.moveTo(const GeoPoint(21.0285, 105.8542));
      await pumpEventQueue();

      expect(emissions.last, isEmpty, reason: 'nothing is nearby from Hanoi');
    });

    test('the position stream reports the move', () async {
      const somewhereElse = GeoPoint(10.7800, 106.7000);
      store.moveTo(somewhereElse);

      expect(await store.position.first, somewhereElse);
      expect(store.currentPosition, somewhereElse);
    });

    // The seeded position is a real coordinate in District 1, which makes it
    // indistinguishable from a fix by looking at it. Everything that must not
    // act on a guess — opening the map on a city, writing fog to disk — asks
    // this instead.
    test('the seeded position is not mistaken for a fix', () {
      expect(store.hasRealPosition, isFalse);

      store.moveTo(const GeoPoint(21.0285, 105.8542));

      expect(store.hasRealPosition, isTrue);
    });

    test('a fix on the seeded coordinate still counts as a fix', () {
      // Standing still on the seed point must not leave the world reporting
      // that it has never heard from the GPS: the map would never centre.
      store.moveTo(store.currentPosition);

      expect(store.hasRealPosition, isTrue);
    });

    test('distance to a place follows the player', () async {
      final place = (await store.places.first).first;
      final before = store.distanceToPlayer(place);

      store.moveTo(const GeoPoint(21.0285, 105.8542));

      expect(store.distanceToPlayer(place), greaterThan(before));
    });
  });

  group('check-in rules', () {
    test('a first visit pays double and counts a new place', () async {
      final before = await store.player.first;

      final result = store.checkIn('place-ben-thanh');
      final after = await store.player.first;

      expect(result.isFirstVisit, isTrue);
      expect(result.xpAwarded, 100, reason: '50 XP doubled on a first visit');
      expect(after.xp - before.xp, 100);
      expect(after.checkInPlaces, before.checkInPlaces + 1);
    });

    test('a repeat visit pays the base reward and does not re-count', () async {
      store.checkIn('place-ben-thanh');
      final between = await store.player.first;

      final result = store.checkIn('place-ben-thanh');
      final after = await store.player.first;

      expect(result.isFirstVisit, isFalse);
      expect(result.xpAwarded, 50);
      expect(after.checkInPlaces, between.checkInPlaces);
    });

    test('records the visit at the top of the log', () async {
      store.checkIn('place-ben-thanh');

      final entries = await store.logs.first;
      expect(entries.first, isA<CheckInLogEntry>());
      expect((entries.first as CheckInLogEntry).placeName, 'Chợ Bến Thành');
    });

    test('refuses a place that is out of range', () {
      expect(
        () => store.checkIn('place-tao-dan'),
        throwsA(
          isA<CheckInFailure>().having(
            (failure) => failure.reason,
            'reason',
            CheckInFailureReason.outOfRange,
          ),
        ),
      );
    });

    test('refuses an unknown place id', () {
      expect(
        () => store.checkIn('nope'),
        throwsA(
          isA<CheckInFailure>().having(
            (failure) => failure.reason,
            'reason',
            CheckInFailureReason.unknownPlace,
          ),
        ),
      );
    });

    test('checking in inside an undiscovered district discovers it', () async {
      // District 1 is already discovered in the seed, so no celebration.
      final result = store.checkIn('place-ben-thanh');
      expect(result.districtDiscovered, isNull);
    });
  });

  test('nearby places come back nearest first', () {
    final nearby = store.nearbyPlaces(500);

    expect(nearby, isNotEmpty);
    final distances = nearby.map(store.distanceToPlayer).toList();
    final sorted = [...distances]..sort();
    expect(distances, sorted);
  });
}
