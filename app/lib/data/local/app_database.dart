import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/geo_point.dart';
import '../../domain/rules/walk_rules.dart';

/// The device's copy of everything the player has made.
///
/// One plain SQLite file, deliberately: it is inspectable. Pull it off the
/// phone and open it in any SQLite browser to see exactly what the app stored —
/// no proprietary format, no framework in the way. The columns are named for
/// people, not for the ORM we do not have.
///
/// ```
/// adb exec-out run-as site.lya3hc.noplace \
///     cat databases/noplace.db > noplace.db
/// ```
///
/// Schema, version 6:
///
/// * `trail_points` — every metre of ground walked, scoped to a region. Primary
///   key is the metre-quantised cell, so re-walking a street is an ignored
///   insert rather than a duplicate row.
/// * `walk_days` — one row per day the player walked, with the metres covered.
///   Not derivable from `trail_points`: that table de-duplicates by cell, so a
///   loop back down the same street is stored once and walked twice.
/// * `map_points` — points the player authored: dropped pins and photo points,
///   with what they called them, how they rated them, how many times they have
///   been there, and how long a stay has to run to count on its own.
/// * `place_visits` — the same visit history for places the player did *not*
///   author: the ones the world came with. Keyed by the place's id rather than
///   stored on the place, because a place is world data a refresh may replace
///   and having stood in it is not.
/// * `preferences` — small key/value settings, so a checkbox does not need a
///   second storage mechanism.
class AppDatabase {
  AppDatabase({Directory? directory}) : _overrideDirectory = directory;

  final Directory? _overrideDirectory;
  Database? _database;

  static const String fileName = 'noplace.db';
  static const int schemaVersion = 6;

  /// Where a trail written before the schema was region-scoped is filed.
  ///
  /// Ho Chi Minh City, because until schema v2 the app had exactly one region
  /// and it was hard-coded to this one — so this is a fact about the old
  /// builds, not an assumption about the player.
  static const String legacyRegionId = 'vn-hcmc';

  Future<Database> open() async {
    final existing = _database;
    if (existing != null) return existing;

    final directory = _overrideDirectory ?? await _defaultDirectory();
    if (!directory.existsSync()) directory.createSync(recursive: true);

    return _database = await openDatabase(
      p.join(directory.path, fileName),
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
  }

  Future<Directory> _defaultDirectory() async =>
      Directory(await getDatabasesPath());

  Future<String> path() async {
    final directory = _overrideDirectory ?? await _defaultDirectory();
    return p.join(directory.path, fileName);
  }

  static Future<void> _createSchema(Database db, int version) async {
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

    // The fog only ever asks "what is in this rectangle, in this region?", and
    // it asks on every camera move. Without this index that is a full scan of
    // the walk of a lifetime.
    await db.execute(
      'CREATE INDEX idx_trail_points_bounds ON trail_points '
      '(region_id, lat_cell, lng_cell)',
    );

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
        stay_last_seen_at INTEGER,
        auto_check_in_minutes INTEGER NOT NULL DEFAULT 60
      )
    ''');

    await db.execute('CREATE INDEX idx_map_points_kind ON map_points (kind)');

    // The same four numbers as the visit half of `map_points`, for places the
    // player did not author. No foreign key: the row outlives whichever build
    // of the places data named that id, and losing somebody's visit count
    // because a refresh renumbered a café would be the worse bug.
    await db.execute('''
      CREATE TABLE place_visits (
        place_id          TEXT    PRIMARY KEY,
        check_in_count    INTEGER NOT NULL DEFAULT 0,
        last_check_in_at  INTEGER,
        claimed_at        INTEGER,
        stay_started_at   INTEGER,
        stay_last_seen_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE preferences (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _createWalkDays(db);
  }

  /// How far the player walked on each day they walked at all.
  ///
  /// A separate table rather than a query over `trail_points`, because that
  /// table cannot answer it: its primary key is the metre-quantised cell, so
  /// walking to the market and back records the way there and drops the way
  /// home. Distance is the thing the player counts, and it has to count the
  /// walk home.
  ///
  /// `day` is a local `YYYY-MM-DD`, not an instant: a streak is about the days
  /// somebody went outside, and that is a question about their calendar.
  static Future<void> _createWalkDays(Database db) => db.execute('''
      CREATE TABLE walk_days (
        day      TEXT    PRIMARY KEY,
        meters   REAL    NOT NULL DEFAULT 0,
        first_at INTEGER NOT NULL,
        last_at  INTEGER NOT NULL
      )
    ''');

  /// One `if` per version step, in order, and every step is tested against a
  /// database created by the previous version — see `sqlite_storage_test`.
  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // v1 → v2: the trail became region-scoped.
    //
    // Every existing row is assigned to [legacyRegionId]. That is not a guess:
    // until this version the app had exactly one region, hard-coded to Ho Chi
    // Minh City, so there is nowhere else a v1 trail could have been walked.
    //
    // Rebuilt rather than `ALTER TABLE ... ADD COLUMN`, because the primary key
    // has to change too, and SQLite cannot alter one in place.
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE trail_points RENAME TO trail_points_v1');
      await db.execute('DROP INDEX IF EXISTS idx_trail_points_bounds');

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
        'CREATE INDEX idx_trail_points_bounds ON trail_points '
        '(region_id, lat_cell, lng_cell)',
      );

      await db.execute(
        '''
        INSERT INTO trail_points
          (region_id, lat_cell, lng_cell, latitude, longitude, recorded_at)
        SELECT ?, lat_cell, lng_cell, latitude, longitude, recorded_at
        FROM trail_points_v1
      ''',
        [legacyRegionId],
      );

      await db.execute('DROP TABLE trail_points_v1');
    }

    // v2 → v3: a point the player made can be rated, given a feeling, and can
    // count its own visits.
    //
    // Added column by column, defaults and all, so an existing pin keeps its
    // name and its icon and simply arrives unrated with nothing recorded — the
    // same state a pin dropped today starts in. The primary key does not move,
    // so unlike v2 there is nothing to rebuild.
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE map_points ADD COLUMN stars INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        "ALTER TABLE map_points ADD COLUMN mood TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'ALTER TABLE map_points ADD COLUMN check_in_count INTEGER NOT NULL '
        'DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE map_points ADD COLUMN last_check_in_at INTEGER',
      );
      await db.execute(
        'ALTER TABLE map_points ADD COLUMN stay_started_at INTEGER',
      );
      await db.execute(
        'ALTER TABLE map_points ADD COLUMN stay_last_seen_at INTEGER',
      );
    }

    // v3 → v4: the world's own places keep a visit history too, and the hour
    // that earns one is now the player's to choose.
    //
    // The default of 60 is what every place did before the setting existed, so
    // a database upgraded by this step behaves on Tuesday exactly as it did on
    // Monday. `place_visits` starts empty: the counts it holds could only have
    // been earned by a build that had it.
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE map_points ADD COLUMN auto_check_in_minutes INTEGER '
        'NOT NULL DEFAULT 60',
      );
      await db.execute('''
        CREATE TABLE place_visits (
          place_id          TEXT    PRIMARY KEY,
          check_in_count    INTEGER NOT NULL DEFAULT 0,
          last_check_in_at  INTEGER,
          stay_started_at   INTEGER,
          stay_last_seen_at INTEGER
        )
      ''');
    }

    // v4 → v5: the world's places can now earn a visit from an hour spent near
    // them, so "has been here" and "has spent the first-visit bonus" stop being
    // the same fact and need two columns.
    //
    // Backfilled from `last_check_in_at`, which is the honest reading of a v4
    // row: until this version the only way to collect a visit to a world place
    // was to tap the button, so every count already on disk *was* claimed. A
    // null backfill would hand every returning player a second first-visit
    // bonus for every place they have ever been to.
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE place_visits ADD COLUMN claimed_at INTEGER',
      );
      await db.execute(
        'UPDATE place_visits SET claimed_at = last_check_in_at '
        'WHERE check_in_count > 0',
      );
    }

    // v5 → v6: the walk keeps a diary.
    //
    // Backfilled from `trail_points`, which is the only record an older build
    // left. It is a lossy one — the table de-duplicates by cell, so a walk home
    // down the street you came up is not in it — and the numbers it yields are
    // therefore floors, not truths. Filling it in anyway is still right: a
    // player who has walked every day this month should open the new build on
    // the streak they earned, not on day one.
    if (oldVersion < 6) {
      await _createWalkDays(db);

      // The diary is a nicety; the walk itself is not. A backfill that trips
      // over an old database's idea of the schema must cost the player their
      // streak, never their trail — and it takes the whole `open()` with it if
      // it is allowed to throw.
      try {
        await rebuildWalkDaysFromTrail(db);
      } on Object catch (error) {
        debugPrint('Database: the walking diary could not be rebuilt ($error)');
      }
    }
  }

  /// Reconstructs the daily distances from the points already on disk, without
  /// ever lowering a day the diary already knows more about.
  ///
  /// One pass in date order, applying [WalkRules] exactly as the live recorder
  /// does, so the gap where the phone was asleep is skipped here for the same
  /// reason it is skipped there.
  ///
  /// Called from two places, and the "without lowering" half is why it is one
  /// method rather than two:
  ///
  ///  * the v6 migration, where the diary does not exist yet and every day this
  ///    finds is new;
  ///  * a restored backup, where trail rows have just arrived from another
  ///    phone. A file written by a build that had no diary carries none, and
  ///    this is the only thing that gets those days back. A file that *does*
  ///    carry one has the truer numbers — the trail cannot see the walk home —
  ///    so those stand and this adds only the days they missed.
  static Future<void> rebuildWalkDaysFromTrail(DatabaseExecutor db) async {
    final rows = await db.query(
      'trail_points',
      columns: ['latitude', 'longitude', 'recorded_at'],
      orderBy: 'recorded_at ASC',
    );
    if (rows.isEmpty) return;

    final meters = <String, double>{};
    final firstAt = <String, int>{};
    final lastAt = <String, int>{};

    GeoPoint? previous;
    DateTime? previousAt;

    for (final row in rows) {
      final at = DateTime.fromMillisecondsSinceEpoch(row['recorded_at']! as int);
      final point = GeoPoint(
        row['latitude']! as double,
        row['longitude']! as double,
      );
      final day = WalkRules.dayOf(at);

      final stamp = at.millisecondsSinceEpoch;
      firstAt.putIfAbsent(day, () => stamp);
      lastAt[day] = stamp;
      meters.putIfAbsent(day, () => 0);

      if (previous != null && previousAt != null) {
        final step = previous.distanceTo(point);
        if (WalkRules.countsAsWalking(step, at.difference(previousAt))) {
          meters[day] = meters[day]! + step;
        }
      }

      previous = point;
      previousAt = at;
    }

    final batch = db.batch();
    for (final day in meters.keys) {
      batch.rawInsert(
        'INSERT INTO walk_days (day, meters, first_at, last_at) '
        'VALUES (?, ?, ?, ?) '
        'ON CONFLICT(day) DO UPDATE SET '
        '  meters   = MAX(meters, excluded.meters),'
        '  first_at = MIN(first_at, excluded.first_at),'
        '  last_at  = MAX(last_at, excluded.last_at)',
        [day, meters[day], firstAt[day], lastAt[day]],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
