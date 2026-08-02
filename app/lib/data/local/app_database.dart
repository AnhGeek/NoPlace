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
/// Schema, version 1:
///
/// * `trail_points` — every metre of ground walked. Primary key is the
///   metre-quantised cell, so re-walking a street is an ignored insert rather
///   than a duplicate row.
/// * `map_points` — points the player authored: dropped pins and photo points.
/// * `preferences` — small key/value settings, so a checkbox does not need a
///   second storage mechanism.
class AppDatabase {
  AppDatabase({Directory? directory}) : _overrideDirectory = directory;

  final Directory? _overrideDirectory;
  Database? _database;

  static const String fileName = 'noplace.db';
  static const int schemaVersion = 2;

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
        id         TEXT    PRIMARY KEY,
        kind       TEXT    NOT NULL,
        latitude   REAL    NOT NULL,
        longitude  REAL    NOT NULL,
        label      TEXT    NOT NULL DEFAULT '',
        icon_id    TEXT    NOT NULL DEFAULT 'pin',
        image_path TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_map_points_kind ON map_points (kind)');

    await db.execute('''
      CREATE TABLE preferences (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// No migrations yet. When the first one lands it goes here, one `if` per
  /// version step, and every step must be tested against a database created by
  /// the previous version.
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
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
