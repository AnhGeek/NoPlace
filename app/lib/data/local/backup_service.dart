import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'sqlite_map_point_repository.dart';
import 'sqlite_preferences_repository.dart';
import 'sqlite_trail_repository.dart';

/// Copies everything the player has made out of the device, and back in.
///
/// The fog is the one thing in this app that cannot be re-earned: a year of
/// walking lives in one SQLite file inside the app's private storage, and it
/// goes with the app when the phone is lost, wiped or replaced. That is the
/// problem this solves, and it is why the format is deliberately dull.
///
/// ## The format
///
/// One file, gzipped UTF-8 JSON, extension `.noplace`. Nothing about it is
/// proprietary — `gunzip < walk.noplace | jq` prints the whole thing, and a
/// backup read by [import] does not have to be gzipped at all, so a file
/// somebody has already unpacked to look at still restores.
///
/// ```json
/// {
///   "format": "noplace.backup",
///   "version": 1,
///   "createdAt": "2026-08-05T09:12:00.000",
///   "trail": [["vn-hcmc", 1198572, 11855364, 10.7725, 106.698, 1754...]],
///   "mapPoints": [{"id": "...", "kind": "user", ...}],
///   "preferences": {"fog.clearing_radius_meters": "180.0"}
/// }
/// ```
///
/// Trail rows are positional rather than named objects because there are a
/// great many of them — a metre-resolution city walk is six figures of rows,
/// and repeating six key names on each one triples the file for nothing.
///
/// ## What it does not carry
///
/// The photos attached to picture points. Their *points* are backed up — where
/// they are, what they are called — but the image files stay on the phone that
/// took them. A restored picture point draws as a plain pin until a photo is
/// attached again. Putting megabytes of camera output inside a backup is a
/// different feature with different tradeoffs, and this one is worth having
/// first.
class BackupService {
  /// The fields have to stay private; the arguments cannot be, because a named
  /// parameter may not start with an underscore.
  BackupService({
    required AppDatabase database,
    required SqliteTrailRepository trail,
    required SqliteMapPointRepository mapPoints,
    required SqlitePreferencesRepository preferences,
    // ignore: prefer_initializing_formals
  }) : _database = database,
       // ignore: prefer_initializing_formals
       _trail = trail,
       // ignore: prefer_initializing_formals
       _mapPoints = mapPoints,
       // ignore: prefer_initializing_formals
       _preferences = preferences;

  final AppDatabase _database;
  final SqliteTrailRepository _trail;
  final SqliteMapPointRepository _mapPoints;
  final SqlitePreferencesRepository _preferences;

  /// Stamped into every file and checked on the way back in, so a JSON file
  /// that is not one of ours is refused rather than half-applied.
  static const String formatId = 'noplace.backup';

  /// Bumped only when an older build could no longer read what we write. A file
  /// from the future is refused: guessing at a shape we have never seen risks
  /// writing nonsense into the one table that cannot be re-earned.
  static const int formatVersion = 1;

  static const String fileExtension = 'noplace';

  /// `noplace-2026-08-05.noplace` — sorts chronologically in any file manager,
  /// which is the only thing a backup name has to do.
  String suggestedFileName([DateTime? now]) {
    final at = now ?? DateTime.now();
    final month = at.month.toString().padLeft(2, '0');
    final day = at.day.toString().padLeft(2, '0');
    return 'noplace-${at.year}-$month-$day.$fileExtension';
  }

  /// Everything on the device, as bytes to hand to a save dialog.
  Future<Uint8List> export() async {
    // Whatever is still in the trail's write buffer is part of the walk being
    // backed up. Without this, a backup taken at the end of a walk is missing
    // its last few minutes — the part the player most likely opened the screen
    // to protect.
    await _trail.flush();

    final db = await _database.open();
    final trail = await db.query('trail_points');
    final mapPoints = await db.query('map_points', orderBy: 'created_at');
    final preferences = await db.query('preferences');

    final document = <String, Object?>{
      'format': formatId,
      'version': formatVersion,
      'createdAt': DateTime.now().toIso8601String(),
      // Not read on the way in. It is here for whoever has to work out, years
      // from now, which schema a strange-looking file came from.
      'schema': AppDatabase.schemaVersion,
      'trail': [
        for (final row in trail)
          [
            row['region_id'],
            row['lat_cell'],
            row['lng_cell'],
            row['latitude'],
            row['longitude'],
            row['recorded_at'],
          ],
      ],
      'mapPoints': mapPoints,
      'preferences': {
        for (final row in preferences) row['key'] as String: row['value'],
      },
    };

    return Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(document))));
  }

  /// Reads [bytes] back into the database and reloads everything on screen.
  ///
  /// **A merge, not a wipe.** Ground walked since the backup was taken stays
  /// walked, and restoring the same file twice changes nothing the second time:
  /// trail rows collide on their primary key and are ignored, and points and
  /// preferences are keyed and replaced. The only thing a restore can overwrite
  /// is a setting the player has changed since — which is the behaviour that
  /// makes "restore onto a new phone" do what it says.
  ///
  /// Throws [BackupFormatException] if the file is not a backup, or is one this
  /// build is too old to read. Nothing is written in either case.
  Future<BackupContents> import(Uint8List bytes) async {
    // Same reason as in [export], one step further: `reload` below reads the
    // trail back from the database, so anything still buffered in memory would
    // be dropped rather than merged.
    await _trail.flush();

    final document = _decode(bytes);
    final trail = _trailRows(document['trail']);
    final mapPoints = _mapPointRows(document['mapPoints']);
    final preferences = _preferenceRows(document['preferences']);

    final db = await _database.open();
    // One transaction for the lot: a restore interrupted halfway is a database
    // in a state nobody designed, and the player has no way to tell.
    await db.transaction((txn) async {
      final batch = txn.batch();

      for (final row in trail) {
        batch.insert(
          'trail_points',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final row in mapPoints) {
        batch.insert(
          'map_points',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final row in preferences) {
        batch.insert(
          'preferences',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });

    // The map is watching all three. Without this the fog on screen is the fog
    // from before the restore, and the player is looking at a screen that
    // disagrees with the file they just fed it.
    await _trail.reload();
    await _mapPoints.reload();
    await _preferences.reload();

    return BackupContents(
      trailPoints: trail.length,
      mapPoints: mapPoints.length,
      preferences: preferences.length,
      regions: {for (final row in trail) row['region_id']! as String}.toList()
        ..sort(),
    );
  }

  /// What is on the device right now, for the screen to show before anything is
  /// backed up. Counting rows is cheap and "3 points" means more than "some".
  Future<BackupContents> currentContents() async {
    final db = await _database.open();

    Future<int> count(String table) async =>
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $table'),
        ) ??
        0;

    final regions = await db.rawQuery(
      'SELECT DISTINCT region_id FROM trail_points ORDER BY region_id',
    );

    return BackupContents(
      trailPoints: await count('trail_points'),
      mapPoints: await count('map_points'),
      preferences: await count('preferences'),
      regions: [for (final row in regions) row['region_id']! as String],
    );
  }

  /// Gzipped or not, and a backup or not.
  static Map<String, Object?> _decode(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(gzip.decode(bytes));
    } on Object {
      // Not gzipped, or not gzip at all. Plain JSON is a supported input: see
      // the class comment.
      try {
        text = utf8.decode(bytes);
      } on Object {
        throw const BackupFormatException(BackupProblem.notABackup);
      }
    }

    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on Object {
      throw const BackupFormatException(BackupProblem.notABackup);
    }

    if (decoded is! Map<String, Object?> || decoded['format'] != formatId) {
      throw const BackupFormatException(BackupProblem.notABackup);
    }

    final version = decoded['version'];
    if (version is! int || version > formatVersion) {
      throw const BackupFormatException(BackupProblem.tooNew);
    }

    return decoded;
  }

  /// A row that does not have the shape we expect is skipped, not fatal.
  ///
  /// The alternative is refusing a whole year of walking over one bad line —
  /// and the rows are independent, so restoring the readable ones is strictly
  /// better than restoring none of them.
  static List<Map<String, Object?>> _trailRows(Object? value) {
    if (value is! List) return const [];

    final rows = <Map<String, Object?>>[];
    for (final entry in value) {
      if (entry is! List || entry.length < 6) continue;
      final regionId = entry[0];
      final latCell = entry[1];
      final lngCell = entry[2];
      final latitude = _asDouble(entry[3]);
      final longitude = _asDouble(entry[4]);
      final recordedAt = entry[5];
      if (regionId is! String ||
          latCell is! int ||
          lngCell is! int ||
          latitude == null ||
          longitude == null ||
          recordedAt is! int) {
        continue;
      }

      rows.add({
        'region_id': regionId,
        'lat_cell': latCell,
        'lng_cell': lngCell,
        'latitude': latitude,
        'longitude': longitude,
        'recorded_at': recordedAt,
      });
    }
    return rows;
  }

  static List<Map<String, Object?>> _mapPointRows(Object? value) {
    if (value is! List) return const [];

    final rows = <Map<String, Object?>>[];
    for (final entry in value) {
      if (entry is! Map) continue;
      final id = entry['id'];
      final latitude = _asDouble(entry['latitude']);
      final longitude = _asDouble(entry['longitude']);
      final createdAt = entry['created_at'];
      if (id is! String || latitude == null || longitude == null) continue;

      rows.add({
        'id': id,
        'kind': entry['kind'] is String ? entry['kind'] : 'user',
        'latitude': latitude,
        'longitude': longitude,
        'label': entry['label'] is String ? entry['label'] : '',
        'icon_id': entry['icon_id'] is String ? entry['icon_id'] : 'pin',
        // Deliberately carried across even though the file it names is on the
        // other phone: the path is the only record of which photo the point
        // had, and a re-import on the original device restores the thumbnail.
        'image_path': entry['image_path'] is String
            ? entry['image_path']
            : null,
        'created_at': createdAt is int
            ? createdAt
            : DateTime.now().millisecondsSinceEpoch,
      });
    }
    return rows;
  }

  static List<Map<String, Object?>> _preferenceRows(Object? value) {
    if (value is! Map) return const [];

    return [
      for (final entry in value.entries)
        if (entry.key is String && entry.value is String)
          {'key': entry.key as String, 'value': entry.value as String},
    ];
  }

  /// JSON turns `10.0` into an `int` on the way out and back, so a coordinate
  /// that happens to land on a whole degree arrives as one.
  static double? _asDouble(Object? value) => switch (value) {
    final double value => value,
    final int value => value.toDouble(),
    _ => null,
  };
}

/// How much a backup holds, or held.
@immutable
class BackupContents {
  const BackupContents({
    required this.trailPoints,
    required this.mapPoints,
    required this.preferences,
    required this.regions,
  });

  const BackupContents.empty()
    : trailPoints = 0,
      mapPoints = 0,
      preferences = 0,
      regions = const [];

  /// Metre-cells of uncovered ground — the fog.
  final int trailPoints;

  /// The player's own pins and photo points.
  final int mapPoints;

  final int preferences;

  /// Which cities the trail covers, sorted.
  final List<String> regions;

  bool get isEmpty => trailPoints == 0 && mapPoints == 0;
}

/// Why a file could not be restored. Two cases, because there are only two the
/// player can do anything about.
enum BackupProblem {
  /// Not a NoPlace backup — the wrong file was picked.
  notABackup,

  /// A backup written by a newer build of the app than this one.
  tooNew,
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.problem);

  final BackupProblem problem;

  @override
  String toString() => 'BackupFormatException($problem)';
}
