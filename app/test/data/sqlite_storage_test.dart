import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/data/local/app_database.dart';
import 'package:noplace/data/local/sqlite_map_point_repository.dart';
import 'package:noplace/data/local/sqlite_place_visit_repository.dart';
import 'package:noplace/data/local/sqlite_preferences_repository.dart';
import 'package:noplace/data/local/sqlite_trail_repository.dart';
import 'package:noplace/domain/entities/auto_check_in.dart';
import 'package:noplace/domain/entities/geo_point.dart';
import 'package:noplace/domain/entities/map_point.dart';
import 'package:noplace/domain/entities/place_visit.dart';
import 'package:noplace/domain/rules/exploration_rules.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // The tests run on the desktop VM, where sqflite needs the FFI factory. The
  // schema and the SQL are the same ones the phone runs.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory directory;
  late AppDatabase database;

  const benThanh = GeoPoint(10.7725, 106.6980);

  // The trail is scoped to a city; these tests are all about one.
  const testRegion = 'vn-hcmc';

  setUp(() {
    directory = Directory.systemTemp.createTempSync('np_db_test');
    database = AppDatabase(directory: directory);
  });

  tearDown(() async {
    await database.close();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  group('trail', () {
    test('a walk survives a restart', () async {
      final first = SqliteTrailRepository(database, regionId: testRegion);
      await first.load();
      await first.record(benThanh);
      await first.flush();

      // A brand new repository over the same file: a cold app launch.
      final second = SqliteTrailRepository(
        AppDatabase(directory: directory),
        regionId: testRegion,
      );
      await second.load();

      expect(second.current.contains(benThanh), isTrue);
    });

    test('re-walking the same metre writes one row', () async {
      final trail = SqliteTrailRepository(database, regionId: testRegion);
      await trail.load();

      await trail.record(benThanh);
      await trail.record(benThanh);
      await trail.record(const GeoPoint(10.772500_1, 106.698000_1));
      await trail.flush();

      final db = await database.open();
      final rows = await db.query('trail_points');
      expect(rows, hasLength(1));
    });

    test('a metre apart is two rows', () async {
      final trail = SqliteTrailRepository(database, regionId: testRegion);
      await trail.load();

      await trail.record(benThanh);
      // ~2 m north.
      await trail.record(const GeoPoint(10.77251797, 106.6980));
      await trail.flush();

      final db = await database.open();
      expect(await db.query('trail_points'), hasLength(2));
    });

    test('stores the real coordinate alongside the cell', () async {
      final trail = SqliteTrailRepository(database, regionId: testRegion);
      await trail.load();
      await trail.record(benThanh);
      await trail.flush();

      final db = await database.open();
      final row = (await db.query('trail_points')).single;

      expect(row['latitude'], closeTo(benThanh.latitude, 0.000001));
      expect(row['longitude'], closeTo(benThanh.longitude, 0.000001));
      expect(row['recorded_at'], isA<int>());
    });

    test('clear empties the table', () async {
      final trail = SqliteTrailRepository(database, regionId: testRegion);
      await trail.load();
      await trail.record(benThanh);
      await trail.flush();
      await trail.clear();

      final db = await database.open();
      expect(await db.query('trail_points'), isEmpty);
      expect(trail.current.isEmpty, isTrue);
    });
  });

  group('trail is scoped to a region', () {
    // Bến Thành, and a point in Hanoi ~1100 km away.
    const hanoi = GeoPoint(21.0285, 105.8542);

    test('switching cities loads that city and only that city', () async {
      final trail = SqliteTrailRepository(database, regionId: 'vn-hcmc');
      await trail.load();
      await trail.record(benThanh);
      await trail.flush();

      await trail.switchTo('vn-hanoi');
      // A city never walked starts empty rather than inheriting the last one.
      expect(trail.current.isEmpty, isTrue);

      await trail.record(hanoi);
      await trail.flush();
      expect(trail.current.contains(hanoi), isTrue);
      expect(trail.current.contains(benThanh), isFalse);

      // And going back finds the first walk exactly as it was left.
      await trail.switchTo('vn-hcmc');
      expect(trail.current.contains(benThanh), isTrue);
      expect(trail.current.contains(hanoi), isFalse);
    });

    test('rows carry the city they were walked in', () async {
      final trail = SqliteTrailRepository(database, regionId: 'vn-hcmc');
      await trail.load();
      await trail.record(benThanh);
      await trail.switchTo('vn-hanoi');
      await trail.record(hanoi);
      await trail.flush();

      final db = await database.open();
      final rows = await db.query('trail_points', columns: ['region_id']);
      expect(rows.map((r) => r['region_id']).toSet(), {'vn-hcmc', 'vn-hanoi'});
    });

    test(
      'switching flushes, so the last metres land in the right city',
      () async {
        final trail = SqliteTrailRepository(database, regionId: 'vn-hcmc');
        await trail.load();
        // Recorded but *not* flushed — this is the walk-to-the-border case.
        await trail.record(benThanh);

        await trail.switchTo('vn-hanoi');

        final db = await database.open();
        final row = (await db.query('trail_points')).single;
        expect(row['region_id'], 'vn-hcmc');
      },
    );

    test('clearing one city leaves the others alone', () async {
      final trail = SqliteTrailRepository(database, regionId: 'vn-hcmc');
      await trail.load();
      await trail.record(benThanh);
      await trail.switchTo('vn-hanoi');
      await trail.record(hanoi);
      await trail.flush();

      await trail.clear();

      await trail.switchTo('vn-hcmc');
      expect(trail.current.contains(benThanh), isTrue);
    });
  });

  group('schema migration', () {
    test('a v1 trail is carried across and filed under HCMC', () async {
      // Build a v1 database by hand, exactly as the shipped build wrote it.
      final path = '${directory.path}/${AppDatabase.fileName}';
      final v1 = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE trail_points (
                lat_cell    INTEGER NOT NULL,
                lng_cell    INTEGER NOT NULL,
                latitude    REAL    NOT NULL,
                longitude   REAL    NOT NULL,
                recorded_at INTEGER NOT NULL,
                PRIMARY KEY (lat_cell, lng_cell)
              )
            ''');
            await db.execute(
              'CREATE INDEX idx_trail_points_bounds ON trail_points '
              '(lat_cell, lng_cell)',
            );
            await db.execute(
              'CREATE TABLE map_points (id TEXT PRIMARY KEY, kind TEXT NOT '
              'NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, label '
              "TEXT NOT NULL DEFAULT '', icon_id TEXT NOT NULL DEFAULT 'pin', "
              'image_path TEXT, created_at INTEGER NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE preferences (key TEXT PRIMARY KEY, value TEXT '
              'NOT NULL)',
            );
          },
        ),
      );
      await v1.insert('trail_points', {
        'lat_cell': 1207121,
        'lng_cell': 11876341,
        'latitude': benThanh.latitude,
        'longitude': benThanh.longitude,
        'recorded_at': 1,
      });
      await v1.close();

      // Opening it with the current build runs the upgrade.
      final upgraded = AppDatabase(directory: directory);
      addTearDown(upgraded.close);

      final trail = SqliteTrailRepository(upgraded, regionId: 'vn-hcmc');
      await trail.load();

      expect(trail.current.count, 1);

      final db = await upgraded.open();
      final row = (await db.query('trail_points')).single;
      expect(row['region_id'], AppDatabase.legacyRegionId);
      expect(row['latitude'], closeTo(benThanh.latitude, 0.000001));
    });

    test('a v2 pin keeps its name and arrives unrated', () async {
      // A v2 database by hand: the shipped schema before places could be rated.
      final path = '${directory.path}/${AppDatabase.fileName}';
      final v2 = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE trail_points (
                region_id   TEXT    NOT NULL,
                lat_cell    INTEGER NOT NULL,
                lng_cell    INTEGER NOT NULL,
                latitude    REAL    NOT NULL,
                longitude   REAL    NOT NULL,
                recorded_at INTEGER NOT NULL,
                PRIMARY KEY (region_id, lat_cell, lng_cell)
              )
            ''');
            await db.execute(
              'CREATE TABLE map_points (id TEXT PRIMARY KEY, kind TEXT NOT '
              'NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, label '
              "TEXT NOT NULL DEFAULT '', icon_id TEXT NOT NULL DEFAULT 'pin', "
              'image_path TEXT, created_at INTEGER NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE preferences (key TEXT PRIMARY KEY, value TEXT '
              'NOT NULL)',
            );
          },
        ),
      );
      await v2.insert('map_points', {
        'id': 'old-pin',
        'kind': 'user',
        'latitude': benThanh.latitude,
        'longitude': benThanh.longitude,
        'label': 'Good bench',
        'icon_id': 'star',
        'created_at': 1,
      });
      await v2.close();

      final upgraded = AppDatabase(directory: directory);
      addTearDown(upgraded.close);

      final points = SqliteMapPointRepository(upgraded);
      await points.load();
      final restored = points.current.single;

      expect(restored.label, 'Good bench');
      expect(restored.iconId, 'star');
      // Unrated, with nothing counted: the state a pin dropped today starts in,
      // which is exactly what this pin's history amounts to.
      expect(restored.stars, 0);
      expect(restored.moodId, PlaceMood.none);
      expect(restored.checkInCount, 0);
      expect(restored.lastCheckInAt, isNull);
      expect(restored.stayStartedAt, isNull);
    });

    test('a v3 pin keeps its history and its hour', () async {
      // A v3 database by hand: the shipped schema before the world's own places
      // kept a history and before the hour was the player's to choose.
      final path = '${directory.path}/${AppDatabase.fileName}';
      final v3 = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE trail_points (
                region_id   TEXT    NOT NULL,
                lat_cell    INTEGER NOT NULL,
                lng_cell    INTEGER NOT NULL,
                latitude    REAL    NOT NULL,
                longitude   REAL    NOT NULL,
                recorded_at INTEGER NOT NULL,
                PRIMARY KEY (region_id, lat_cell, lng_cell)
              )
            ''');
            await db.execute('''
              CREATE TABLE map_points (
                id                TEXT    PRIMARY KEY,
                kind              TEXT    NOT NULL,
                latitude          REAL    NOT NULL,
                longitude         REAL    NOT NULL,
                label             TEXT    NOT NULL DEFAULT '',
                icon_id           TEXT    NOT NULL DEFAULT 'pin',
                image_path        TEXT,
                created_at        INTEGER NOT NULL,
                stars             INTEGER NOT NULL DEFAULT 0,
                mood              TEXT    NOT NULL DEFAULT '',
                check_in_count    INTEGER NOT NULL DEFAULT 0,
                last_check_in_at  INTEGER,
                stay_started_at   INTEGER,
                stay_last_seen_at INTEGER
              )
            ''');
            await db.execute(
              'CREATE TABLE preferences (key TEXT PRIMARY KEY, value TEXT '
              'NOT NULL)',
            );
          },
        ),
      );
      await v3.insert('map_points', {
        'id': 'the-cafe',
        'kind': 'user',
        'latitude': benThanh.latitude,
        'longitude': benThanh.longitude,
        'label': 'The café',
        'icon_id': 'coffee',
        'created_at': 1,
        'stars': 4,
        'mood': PlaceMood.calm,
        'check_in_count': 6,
        'last_check_in_at': DateTime(2026, 8, 4, 18).millisecondsSinceEpoch,
      });
      await v3.close();

      final upgraded = AppDatabase(directory: directory);
      addTearDown(upgraded.close);

      final points = SqliteMapPointRepository(upgraded);
      await points.load();
      final restored = points.current.single;

      expect(restored.stars, 4);
      expect(restored.checkInCount, 6);
      // The hour it was already keeping, now written down. Anything else here
      // would change what this pin does on the morning after an update.
      expect(restored.autoCheckInEvery, AutoCheckIn.hourly);

      // And the new table exists, empty: the counts it would hold could only
      // have been earned by a build that had it.
      final visits = SqlitePlaceVisitRepository(upgraded);
      await visits.load();
      expect(visits.current, isEmpty);
    });
  });

  group('place visits', () {
    test('round-trip and overwrite the same place', () async {
      final visits = SqlitePlaceVisitRepository(database);
      await visits.load();

      expect(visits.of('place-ben-thanh').checkInCount, 0);
      expect(visits.of('place-ben-thanh').hasVisited, isFalse);

      await visits.save(
        PlaceVisit(
          placeId: 'place-ben-thanh',
          checkInCount: 1,
          lastCheckInAt: DateTime(2026, 8, 4, 14, 20),
        ),
      );
      await visits.save(
        PlaceVisit(
          placeId: 'place-ben-thanh',
          checkInCount: 2,
          lastCheckInAt: DateTime(2026, 8, 5, 9),
        ),
      );

      // Read back off disk rather than out of memory: the point of the table is
      // that the count is still there next launch.
      final reopened = SqlitePlaceVisitRepository(database);
      await reopened.load();

      expect(reopened.current, hasLength(1));
      expect(reopened.of('place-ben-thanh').checkInCount, 2);
      expect(
        reopened.of('place-ben-thanh').lastCheckInAt,
        DateTime(2026, 8, 5, 9),
      );
    });

    test('keeps the world places apart from each other', () async {
      final visits = SqlitePlaceVisitRepository(database);
      await visits.load();

      await visits.save(
        const PlaceVisit(placeId: 'place-ben-thanh', checkInCount: 3),
      );
      await visits.save(
        const PlaceVisit(placeId: 'place-tao-dan', checkInCount: 1),
      );

      expect(visits.of('place-ben-thanh').checkInCount, 3);
      expect(visits.of('place-tao-dan').checkInCount, 1);
      expect(visits.of('place-notre-dame').checkInCount, 0);
    });
  });

  group('map points', () {
    MapPoint point(String id, MapPointKind kind) => MapPoint(
      id: id,
      kind: kind,
      location: benThanh,
      createdAt: DateTime(2026, 7, 31),
      label: 'Test $id',
      iconId: 'star',
    );

    test('round-trips through the database', () async {
      final repository = SqliteMapPointRepository(database);
      await repository.load();
      await repository.add(point('p1', MapPointKind.user));

      final reopened = SqliteMapPointRepository(
        AppDatabase(directory: directory),
      );
      await reopened.load();

      expect(reopened.current, hasLength(1));
      expect(reopened.current.single.label, 'Test p1');
      expect(reopened.current.single.kind, MapPointKind.user);
      expect(reopened.current.single.iconId, 'star');
    });

    test('keeps picture points distinct from dropped pins', () async {
      final repository = SqliteMapPointRepository(database);
      await repository.load();
      await repository.add(point('pin', MapPointKind.user));
      await repository.add(point('photo', MapPointKind.picture));

      final kinds = repository.current.map((p) => p.kind).toSet();
      expect(kinds, {MapPointKind.user, MapPointKind.picture});
    });

    test('remove deletes it everywhere', () async {
      final repository = SqliteMapPointRepository(database);
      await repository.load();
      await repository.add(point('p1', MapPointKind.user));
      await repository.remove('p1');

      final db = await database.open();
      expect(await db.query('map_points'), isEmpty);
      expect(repository.current, isEmpty);
    });

    test('a rating, a feeling and a visit count round-trip', () async {
      final repository = SqliteMapPointRepository(database);
      await repository.load();
      await repository.add(
        point('p1', MapPointKind.user).copyWith(
          stars: 4,
          moodId: PlaceMood.calm,
          checkInCount: 3,
          lastCheckInAt: DateTime(2026, 8, 5, 18, 30),
          stayStartedAt: DateTime(2026, 8, 5, 18),
          stayLastSeenAt: DateTime(2026, 8, 5, 18, 25),
        ),
      );

      final reopened = SqliteMapPointRepository(
        AppDatabase(directory: directory),
      );
      await reopened.load();
      final restored = reopened.current.single;

      expect(restored.stars, 4);
      expect(restored.moodId, PlaceMood.calm);
      expect(restored.checkInCount, 3);
      expect(restored.lastCheckInAt, DateTime(2026, 8, 5, 18, 30));
      // The stay survives a restart, which is the only reason an hour at a café
      // can span one.
      expect(restored.stayStartedAt, DateTime(2026, 8, 5, 18));
      expect(restored.stayLastSeenAt, DateTime(2026, 8, 5, 18, 25));
    });

    test('a hand-edited star count cannot get past the entity', () async {
      final repository = SqliteMapPointRepository(database);
      await repository.load();
      await repository.add(point('p1', MapPointKind.user));

      // The database file is meant to be opened and poked at; the app still has
      // to survive what comes back out of it.
      final db = await database.open();
      await db.update('map_points', {'stars': 99});

      final reopened = SqliteMapPointRepository(
        AppDatabase(directory: directory),
      );
      await reopened.load();

      expect(reopened.current.single.stars, MapPoint.maxStars);
    });

    test('seeding never touches a table the player has written to', () async {
      final repository = SqliteMapPointRepository(database);
      await repository.load();
      await repository.add(point('mine', MapPointKind.user));

      await repository.seedIfEmpty([point('seeded', MapPointKind.user)]);

      expect(repository.current.map((p) => p.id), ['mine']);
    });
  });

  group('preferences', () {
    test('everything is visible by default', () async {
      final preferences = SqlitePreferencesRepository(database);
      await preferences.load();

      expect(preferences.currentVisibility.showSuggested, isTrue);
      expect(preferences.currentVisibility.showUser, isTrue);
      expect(preferences.currentVisibility.showPictures, isTrue);
      expect(preferences.currentVisibility.showFog, isTrue);
    });

    test('lifting the fog survives a restart', () async {
      final preferences = SqlitePreferencesRepository(database);
      await preferences.load();
      await preferences.setFogVisible(visible: false);

      final reopened = SqlitePreferencesRepository(
        AppDatabase(directory: directory),
      );
      await reopened.load();

      expect(reopened.currentVisibility.showFog, isFalse);
      // Hiding the fog is a change to one layer, not to the map.
      expect(reopened.currentVisibility.showUser, isTrue);
      expect(reopened.currentVisibility.showSuggested, isTrue);
    });

    test('hiding a layer survives a restart', () async {
      final preferences = SqlitePreferencesRepository(database);
      await preferences.load();
      await preferences.setMapLayerVisible(
        MapPointKind.picture,
        visible: false,
      );

      final reopened = SqlitePreferencesRepository(
        AppDatabase(directory: directory),
      );
      await reopened.load();

      expect(reopened.currentVisibility.showPictures, isFalse);
      expect(reopened.currentVisibility.showUser, isTrue);
      expect(reopened.currentVisibility.showSuggested, isTrue);
    });

    test('the nearby radius defaults to 2 km and survives a restart', () async {
      final preferences = SqlitePreferencesRepository(database);
      await preferences.load();

      expect(
        preferences.currentNearbyRadiusMeters,
        ExplorationRules.defaultNearbyRadiusMeters,
      );

      await preferences.setNearbyRadiusMeters(5000);

      final reopened = SqlitePreferencesRepository(
        AppDatabase(directory: directory),
      );
      await reopened.load();

      expect(reopened.currentNearbyRadiusMeters, 5000);
    });

    test('the background question is asked once, not once a launch', () async {
      final preferences = SqlitePreferencesRepository(database);
      await preferences.load();

      // Never asked yet is the only state that shows the sheet.
      expect(preferences.currentBackgroundPromptSeen, isFalse);

      await preferences.markBackgroundPromptSeen();

      final reopened = SqlitePreferencesRepository(
        AppDatabase(directory: directory),
      );
      await reopened.load();

      expect(reopened.currentBackgroundPromptSeen, isTrue);
    });

    test('the stream reports the change', () async {
      final preferences = SqlitePreferencesRepository(database);
      await preferences.load();

      final updates = preferences.watchMapLayerVisibility();
      final future = updates.firstWhere((v) => !v.showUser);

      await preferences.setMapLayerVisible(MapPointKind.user, visible: false);

      expect((await future).showUser, isFalse);
    });
  });
}
