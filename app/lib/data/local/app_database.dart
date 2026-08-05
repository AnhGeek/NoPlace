import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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
/// Schema, version 4:
///
/// * `trail_points` — every metre of ground walked, scoped to a region. Primary
///   key is the metre-quantised cell, so re-walking a street is an ignored
///   insert rather than a duplicate row.
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
  static const int schemaVersion = 4;

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
  }

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
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
