import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/data/fake/fake_world_store.dart';
import 'package:noplace/data/local/region_catalogue.dart';
import 'package:noplace/data/repository_providers.dart';
import 'package:noplace/domain/entities/geo_point.dart';

/// Coordinates a person could stand on, not made-up ones: getting the region
/// wrong is not an abstraction, it is somebody opening the app in Biên Hòa and
/// being shown the wrong city.
const benThanh = GeoPoint(10.7725, 106.6980);
const bienHoa = GeoPoint(10.9574, 106.8426);
const longKhanh = GeoPoint(10.9367, 107.2400);
const hoanKiem = GeoPoint(21.0285, 105.8542);
const bangkok = GeoPoint(13.7563, 100.5018);

void main() {
  group('resolving a region from a position', () {
    test('Ho Chi Minh City', () {
      expect(RegionCatalogue.forPosition(benThanh), RegionCatalogue.hcmc);
    });

    test('Đồng Nai — both ends of the province', () {
      expect(RegionCatalogue.forPosition(bienHoa), RegionCatalogue.dongNai);
      expect(RegionCatalogue.forPosition(longKhanh), RegionCatalogue.dongNai);
    });

    test('Hanoi', () {
      expect(RegionCatalogue.forPosition(hoanKiem), RegionCatalogue.hanoi);
    });

    test('somewhere we have no map for resolves to nothing', () {
      expect(RegionCatalogue.forPosition(bangkok), isNull);
    });

    // The claims decide who owns a metre of ground, so two of them owning the
    // same metre is a coin toss dressed up as a rule.
    test('no two regions claim the same ground', () {
      for (final a in RegionCatalogue.all) {
        for (final b in RegionCatalogue.all) {
          if (identical(a, b)) continue;
          final one = a.bounds!;
          final other = b.bounds!;
          final overlaps =
              one.minLongitude < other.maxLongitude &&
              one.maxLongitude > other.minLongitude &&
              one.minLatitude < other.maxLatitude &&
              one.maxLatitude > other.minLatitude;
          expect(
            overlaps,
            isFalse,
            reason: '${a.regionId} and ${b.regionId} claim the same ground',
          );
        }
      }
    });
  });

  group('the region the app opens', () {
    ProviderContainer containerWith(FakeWorldStore store) {
      final container = ProviderContainer(
        overrides: [fakeWorldStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('is the fallback until the GPS has actually said something', () {
      final store = FakeWorldStore();
      final container = containerWith(store);

      // The world starts on a seeded coordinate in District 1. It resolves to
      // HCMC, but only by accident — the point is that no *fix* has arrived.
      expect(
        container.read(regionPackSourceProvider),
        RegionCatalogue.fallback,
      );
    });

    test('follows the player across a border', () async {
      final store = FakeWorldStore();
      final container = containerWith(store);

      // Kept alive the way the map keeps it alive; without a listener the
      // notifier is never built and never hears the fix.
      final subscription = container.listen(
        regionPackSourceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      store.moveTo(bienHoa);
      await pumpEventQueue();

      expect(container.read(regionPackSourceProvider), RegionCatalogue.dongNai);
    });

    test('a crossing is announced once, and only once', () async {
      final store = FakeWorldStore();
      final container = containerWith(store);
      final subscription = container.listen(
        regionPackSourceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      expect(container.read(regionArrivalProvider), isNull);

      store.moveTo(bienHoa);
      await pumpEventQueue();

      final arrival = container.read(regionArrivalProvider.notifier).take();
      expect(arrival, RegionCatalogue.dongNai);

      // Walking on inside the same region is not a new arrival. Without this
      // the sheet would reopen on every fix for as long as the player stayed
      // in Đồng Nai.
      store.moveTo(longKhanh);
      await pumpEventQueue();
      expect(container.read(regionArrivalProvider), isNull);
    });

    test('the player can pick another map and keep it', () async {
      final store = FakeWorldStore();
      final container = containerWith(store);
      final subscription = container.listen(
        regionPackSourceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      store.moveTo(bienHoa);
      await pumpEventQueue();

      container
          .read(regionPackSourceProvider.notifier)
          .select(RegionCatalogue.hcmc);
      expect(container.read(regionPackSourceProvider), RegionCatalogue.hcmc);

      // Still standing in Đồng Nai. The next fix must not undo the choice —
      // the ground has not changed region, so nothing has.
      store.moveTo(bienHoa);
      await pumpEventQueue();

      expect(
        container.read(regionPackSourceProvider),
        RegionCatalogue.hcmc,
        reason: 'a fix in the region already resolved must not override a pick',
      );

      // Actually crossing back does move the map again.
      store.moveTo(benThanh);
      await pumpEventQueue();
      store.moveTo(bienHoa);
      await pumpEventQueue();

      expect(container.read(regionPackSourceProvider), RegionCatalogue.dongNai);
    });

    test('a fix outside every region keeps the one we are on', () async {
      final store = FakeWorldStore();
      final container = containerWith(store);
      final subscription = container.listen(
        regionPackSourceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      store.moveTo(bienHoa);
      await pumpEventQueue();
      store.moveTo(bangkok);
      await pumpEventQueue();

      expect(
        container.read(regionPackSourceProvider),
        RegionCatalogue.dongNai,
        reason: 'walking off the map must not move the fog to another city',
      );
    });
  });
}
