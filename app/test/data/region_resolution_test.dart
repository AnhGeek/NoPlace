import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/data/fake/fake_world_store.dart';
import 'package:noplace/data/local/app_database.dart';
import 'package:noplace/data/local/region_catalogue.dart';
import 'package:noplace/data/local/sqlite_preferences_repository.dart';
import 'package:noplace/data/repository_providers.dart';
import 'package:noplace/domain/entities/geo_point.dart';
import 'package:noplace/domain/repositories/repositories.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Coordinates a person could stand on, not made-up ones: getting the region
/// wrong is not an abstraction, it is somebody opening the app in Biên Hòa and
/// being shown the wrong city.
const benThanh = GeoPoint(10.7725, 106.6980);
const bienHoa = GeoPoint(10.9574, 106.8426);
const longKhanh = GeoPoint(10.9367, 107.2400);
const hoanKiem = GeoPoint(21.0285, 105.8542);
const bangkok = GeoPoint(13.7563, 100.5018);

/// Either side of the Đồng Nai river, a few hundred metres apart: two different
/// claims, one walk, and nothing that deserves to be called moving city.
const riverWest = GeoPoint(10.9100, 106.7990);
const riverEast = GeoPoint(10.9100, 106.8010);

/// A phone that has never been anywhere: everything defaulted, nothing kept.
///
/// Only [PreferencesRepository.lastFix] is reachable from the region code, so
/// the rest is deliberately inert rather than a second implementation to keep
/// in step with the real one.
class _NoMemory implements PreferencesRepository {
  @override
  GeoPoint? get lastFix => null;

  @override
  Future<void> saveLastFix(GeoPoint position) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not under test');
}

void main() {
  ProviderContainer containerWith(
    FakeWorldStore store, {
    PreferencesRepository? preferences,
  }) {
    final container = ProviderContainer(
      overrides: [
        fakeWorldStoreProvider.overrideWithValue(store),
        // The region is written down as it is worked out, so there is always
        // something underneath this — a phone with nothing remembered on it,
        // unless the test is about what was.
        preferencesRepositoryProvider.overrideWithValue(
          preferences ?? _NoMemory(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

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

    test('a border crossed by a few hundred metres is not a new city', () async {
      final store = FakeWorldStore();
      final container = containerWith(store);
      final subscription = container.listen(
        regionPackSourceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      store.moveTo(riverWest);
      await pumpEventQueue();
      expect(container.read(regionArrivalProvider.notifier).take(), isNotNull);

      // Two claims, one walk. Believing this would swap the streets and reload
      // the fog for somebody who has not left the neighbourhood.
      store.moveTo(riverEast);
      await pumpEventQueue();

      expect(container.read(regionPackSourceProvider), RegionCatalogue.hcmc);
      expect(container.read(regionArrivalProvider), isNull);

      // Actually going there still counts.
      store.moveTo(bienHoa);
      await pumpEventQueue();

      expect(container.read(regionPackSourceProvider), RegionCatalogue.dongNai);
      expect(container.read(regionArrivalProvider), RegionCatalogue.dongNai);
    });
  });

  // The complaint this answers: the app asked "which city is this?" on every
  // single cold start, because nothing on the device remembered the answer.
  group('the region the app remembers', () {
    // Over the real file, not a double: what is under test is whether the
    // answer survives the app being closed, and only the database can say.
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    late Directory directory;
    late List<AppDatabase> opened;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('np_region');
      opened = [];
    });

    tearDown(() async {
      // The fix is written down without waiting for the write, so let the
      // pending ones land before pulling the file out from under them.
      await pumpEventQueue();

      // Windows will not delete a directory while anything still holds the
      // file open, and every launch below opens it again.
      for (final database in opened) {
        await database.close();
      }
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    /// A preferences store over the same file the last launch wrote to.
    Future<SqlitePreferencesRepository> reopened() async {
      final database = AppDatabase(directory: directory);
      opened.add(database);
      final preferences = SqlitePreferencesRepository(database);
      await preferences.load();
      return preferences;
    }

    Future<void> lastSeenAt(GeoPoint position) async {
      final preferences = await reopened();
      await preferences.saveLastFix(position);
    }

    test('a fix is written down when the city is worked out', () async {
      final store = FakeWorldStore();
      final container = containerWith(store, preferences: await reopened());
      final subscription = container.listen(
        regionPackSourceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      store.moveTo(bienHoa);
      await pumpEventQueue();

      expect((await reopened()).lastFix, bienHoa);
    });

    test('opens on the city the device was last in', () async {
      await lastSeenAt(bienHoa);
      final container = containerWith(
        FakeWorldStore(),
        preferences: await reopened(),
      );

      // Not the fallback, and not a guess: the GPS has said nothing yet, so the
      // best answer available is where this phone was standing last time.
      expect(container.read(regionPackSourceProvider), RegionCatalogue.dongNai);
    });

    test('opening the app in the same city asks nothing', () async {
      await lastSeenAt(bienHoa);
      final store = FakeWorldStore();
      final container = containerWith(store, preferences: await reopened());
      final subscription = container.listen(
        regionPackSourceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      // A morning's walk across Biên Hòa. None of it is news.
      store.moveTo(bienHoa);
      await pumpEventQueue();
      store.moveTo(longKhanh);
      await pumpEventQueue();

      expect(container.read(regionPackSourceProvider), RegionCatalogue.dongNai);
      expect(container.read(regionArrivalProvider), isNull);
    });

    test('opening the app somewhere new still asks', () async {
      await lastSeenAt(bienHoa);
      final store = FakeWorldStore();
      final container = containerWith(store, preferences: await reopened());
      final subscription = container.listen(
        regionPackSourceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      store.moveTo(hoanKiem);
      await pumpEventQueue();

      expect(container.read(regionPackSourceProvider), RegionCatalogue.hanoi);
      expect(container.read(regionArrivalProvider), RegionCatalogue.hanoi);
    });

    test('the first launch of all still asks', () async {
      final store = FakeWorldStore();
      final container = containerWith(store, preferences: await reopened());
      final subscription = container.listen(
        regionPackSourceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      store.moveTo(benThanh);
      await pumpEventQueue();

      // Nothing on the device to compare against, so this genuinely is an
      // arrival — and it is the moment the picker is most worth showing.
      expect(container.read(regionArrivalProvider), RegionCatalogue.hcmc);
    });
  });
}
