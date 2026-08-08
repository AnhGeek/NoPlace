import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/async/replay_subject.dart';
import '../../domain/entities/explored_area.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/walk_history.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/rules/exploration_rules.dart';
import '../../domain/rules/walk_rules.dart';
import 'app_database.dart';

/// The walked trail, in SQLite, one region at a time.
///
/// Every position fix is quantised to a metre and inserted with
/// `INSERT OR IGNORE`, so the primary key does the de-duplication: standing
/// still for ten minutes writes one row, and re-walking a street writes none.
///
/// Writes are batched. A fix arrives every second or two; committing each one
/// separately would mean a transaction per second for the length of a walk.
///
/// **Scoped to a region.** The store holds one region's cells in memory and the
/// database keeps the rest. Cells are absolute world coordinates, so scoping is
/// not what stops Hà Nội's fog appearing over Ho Chi Minh City — the fog layer
/// culls to the viewport and another city is simply off screen. What it buys is
/// everything else: start-up reads one city instead of a lifetime, and
/// "charted", "clear this trail" and eventual sync all have a subject.
class SqliteTrailRepository implements ExplorationTrailRepository {
  SqliteTrailRepository(this._database, {required String regionId})
    // `this._regionId` would make the named parameter private and so
    // unusable by callers. The field has to stay private; the argument does not.
    // ignore: prefer_initializing_formals
    : _regionId = regionId;

  final AppDatabase _database;

  /// The region every read and write below is about.
  String _regionId;

  String get regionId => _regionId;

  final ReplaySubject<ExploredArea> _area = ReplaySubject(
    const ExploredArea.empty(),
  );

  final List<_PendingPoint> _pending = [];
  Timer? _flushTimer;
  Future<void>? _inFlight;
  bool _loaded = false;

  static const Duration _flushDelay = Duration(seconds: 3);

  /// Metres walked on each day the player walked at all, keyed by
  /// [WalkRules.dayOf].
  ///
  /// Held in memory in full because it is small — a year of walking is 365
  /// rows — and because the two questions asked of it, "how far today" and "how
  /// many days in a row", are both answered from the whole set.
  final Map<String, double> _daysWalked = {};

  /// Days with metres not yet written. Flushed on the same timer as the points.
  final Set<String> _dirtyDays = {};

  final ReplaySubject<WalkHistory> _history = ReplaySubject(
    const WalkHistory.empty(),
  );

  @override
  Stream<ExploredArea> watch() => _area.stream;

  @override
  Stream<WalkHistory> watchHistory() => _history.stream;

  ExploredArea get current => _area.value;

  WalkHistory get currentHistory => _history.value;

  /// Reads the whole trail into memory.
  ///
  /// Honest about its limits: this is fine for a city (a hundred thousand
  /// points is a few megabytes) and wrong for a lifetime. The fog only ever
  /// draws what is on screen, so the scaling fix is a bounded query per camera
  /// move — see docs/backlog.md.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    await _read();
  }

  /// Reads this region's trail again, for when the database has changed
  /// underneath us — which today means a restored backup.
  ///
  /// The caller is responsible for flushing first: this replaces what is in
  /// memory with what is on disk, so anything still buffered would be lost.
  Future<void> reload() async {
    _loaded = true;
    _lastRecorded = null;
    _lastRecordedAt = null;
    await _read();
  }

  /// Moves to another region: flushes what is pending, then loads that
  /// region's trail. A region never walked before starts empty.
  ///
  /// The caller decides *when* this is safe. Crossing a border mid-walk swaps
  /// the fog under the player, so NP-1 announces the new region rather than
  /// doing it silently — see docs/tickets/NP-1-region-packs-on-device.md.
  Future<void> switchTo(String regionId) async {
    if (regionId == _regionId) return;

    // Pending points belong to the region they were walked in. Writing them
    // first is the difference between the last few metres of a walk landing in
    // the right city and landing in the next one.
    await flush();

    _regionId = regionId;
    // The next fix in the new city is not a step taken from the last one in the
    // old one, however close the border was.
    _lastRecorded = null;
    _lastRecordedAt = null;
    _loaded = true;
    await _read();
  }

  Future<void> _read() async {
    try {
      final db = await _database.open();
      final rows = await db.query(
        'trail_points',
        columns: ['lat_cell', 'lng_cell'],
        where: 'region_id = ?',
        whereArgs: [_regionId],
      );
      _area.value = ExploredArea({
        for (final row in rows)
          TrailCell(row['lat_cell']! as int, row['lng_cell']! as int),
      });
    } on Object catch (error) {
      // A trail we cannot read must never stop the app from starting.
      debugPrint('Trail: could not be read ($error)');
    }

    await _readDays();
  }

  /// The walking diary, which unlike the trail is not scoped to a region: a
  /// streak is a fact about the player, and crossing a river on foot on the
  /// Tuesday does not cost them the Tuesday.
  Future<void> _readDays() async {
    try {
      final db = await _database.open();
      final rows = await db.query('walk_days', columns: ['day', 'meters']);

      _daysWalked
        ..clear()
        ..addEntries(
          rows.map(
            (row) => MapEntry(row['day']! as String, row['meters']! as double),
          ),
        );
      _publishHistory();
    } on Object catch (error) {
      debugPrint('Trail: the walking diary could not be read ($error)');
    }
  }

  void _publishHistory() {
    final now = DateTime.now();
    var total = 0.0;
    for (final meters in _daysWalked.values) {
      total += meters;
    }

    _history.value = WalkHistory(
      distanceTodayMeters: _daysWalked[WalkRules.dayOf(now)] ?? 0,
      distanceTotalMeters: total,
      streakDays: WalkRules.streakOf(_daysWalked.keys.toSet(), now: now),
      daysWalked: _daysWalked.length,
    );
  }

  /// Minimum distance between two recorded positions.
  ///
  /// The grid is always a metre — that is the resolution the database keeps, so
  /// an exported trail is always the finest record we had. This is the throttle
  /// in front of it: at 1 m every metre walked is a row, at 25 m the same walk
  /// is twenty-five times smaller. Changed from Settings; see [FogSettings].
  double recordingPrecisionMeters =
      ExplorationRules.defaultRecordingPrecisionMeters;

  GeoPoint? _lastRecorded;

  /// When [_lastRecorded] arrived. Half of the test for whether the ground
  /// between the two was walked — see [WalkRules.countsAsWalking].
  DateTime? _lastRecordedAt;

  @override
  Future<void> record(GeoPoint point) async {
    final last = _lastRecorded;
    if (last != null && last.distanceTo(point) < recordingPrecisionMeters) {
      return;
    }

    final now = DateTime.now();
    // Before the de-duplication below, deliberately. Walking home down the
    // street you came up adds no cells — the ground was already uncovered — but
    // it is half the distance of the walk, and the diary is where that half
    // would otherwise be lost.
    _countTowardsToday(from: last, to: point, at: now, since: _lastRecordedAt);

    _lastRecorded = point;
    _lastRecordedAt = now;

    final cell = TrailCell.of(point);
    if (_area.value.cells.contains(cell)) return;

    _area.value = ExploredArea({..._area.value.cells, cell});
    // Tagged with the region it was walked in, not the one current at flush
    // time. `switchTo` flushes before it moves, so these agree — the tag is
    // what keeps that true if that ever stops being the case.
    _pending.add(_PendingPoint(_regionId, cell, point, DateTime.now()));

    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDelay, () => unawaited(flush()));
  }

  /// Adds the step from [from] to [to] to today's total, if it was walked.
  ///
  /// A day appears in the diary the moment anything is recorded on it, even
  /// when the step itself is refused: somebody who opened the app on a hilltop
  /// and stood there was still out, and the streak is about going out.
  void _countTowardsToday({
    required GeoPoint? from,
    required GeoPoint to,
    required DateTime at,
    required DateTime? since,
  }) {
    final day = WalkRules.dayOf(at);
    final before = _daysWalked[day];
    var meters = before ?? 0;

    if (from != null && since != null) {
      final step = from.distanceTo(to);
      if (WalkRules.countsAsWalking(step, at.difference(since))) {
        meters += step;
      }
    }

    // A day that gained no metres and was already open is not news, and
    // re-publishing would rebuild every widget watching the history for
    // nothing.
    if (before != null && meters == before) return;

    _daysWalked[day] = meters;
    _dirtyDays.add(day);
    _publishHistory();
  }

  @override
  Future<void> flush() async {
    _flushTimer?.cancel();
    await _writeDays();
    if (_pending.isEmpty) return;

    await _inFlight;
    final batchToWrite = List<_PendingPoint>.of(_pending);
    _pending.clear();
    _inFlight = _writeBatch(batchToWrite);
    await _inFlight;
  }

  Future<void> _writeDays() async {
    if (_dirtyDays.isEmpty) return;

    final days = Set<String>.of(_dirtyDays);
    _dirtyDays.clear();

    try {
      final db = await _database.open();
      final now = DateTime.now().millisecondsSinceEpoch;
      final batch = db.batch();
      for (final day in days) {
        // The first sighting of a day is whichever write got there first, so
        // `first_at` is only set on insert; every write moves `last_at`.
        batch.rawInsert(
          'INSERT INTO walk_days (day, meters, first_at, last_at) '
          'VALUES (?, ?, ?, ?) '
          'ON CONFLICT(day) DO UPDATE SET meters = ?, last_at = ?',
          [day, _daysWalked[day], now, now, _daysWalked[day], now],
        );
      }
      await batch.commit(noResult: true);
    } on Object catch (error) {
      // Put them back so the next flush retries rather than losing the day.
      _dirtyDays.addAll(days);
      debugPrint('Trail: the walking diary could not be saved ($error)');
    }
  }

  Future<void> _writeBatch(List<_PendingPoint> points) async {
    try {
      final db = await _database.open();
      final batch = db.batch();
      for (final point in points) {
        batch.insert('trail_points', {
          'region_id': point.regionId,
          'lat_cell': point.cell.latIndex,
          'lng_cell': point.cell.lngIndex,
          'latitude': point.position.latitude,
          'longitude': point.position.longitude,
          'recorded_at': point.at.millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    } on Object catch (error) {
      // Put them back so the next flush retries rather than losing a walk.
      _pending.insertAll(0, points);
      debugPrint('Trail: could not be saved ($error)');
    }
  }

  /// Wipes **this region's** trail and leaves every other city alone.
  ///
  /// Deliberately not "clear everything": a player asking to reset the city
  /// they are standing in has not asked to lose the one they walked last year.
  ///
  /// The walking diary survives too, and for the same reason. Clearing the fog
  /// is asking to walk this city again; it is not a claim that the last four
  /// months of mornings never happened.
  @override
  Future<void> clear() async {
    _pending.clear();
    _lastRecorded = null;
    _lastRecordedAt = null;
    _area.value = const ExploredArea.empty();
    final db = await _database.open();
    await db.delete(
      'trail_points',
      where: 'region_id = ?',
      whereArgs: [_regionId],
    );
  }

  /// Imports a trail written by the previous JSON store, then removes it.
  ///
  /// Cheap insurance for anyone carrying a build from before the database
  /// existed: their walk moves across instead of vanishing.
  Future<void> importLegacyJson(File file) async {
    if (!file.existsSync()) return;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return;
      final legacyCellSize = decoded['cellSizeDegrees'] as double? ?? 0.00036;

      final points = <GeoPoint>[];
      for (final entry in (decoded['cells'] as List<Object?>? ?? const [])) {
        final pair = entry! as List<Object?>;
        points.add(
          GeoPoint(
            ((pair[0]! as int) + 0.5) * legacyCellSize,
            ((pair[1]! as int) + 0.5) * legacyCellSize,
          ),
        );
      }

      for (final point in points) {
        await record(point);
      }
      await flush();
      await file.delete();
      debugPrint('Trail: imported ${points.length} points from the JSON store');
    } on Object catch (error) {
      debugPrint('Trail: legacy import skipped ($error)');
    }
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    await flush();
    await _area.close();
    await _history.close();
  }
}

class _PendingPoint {
  const _PendingPoint(this.regionId, this.cell, this.position, this.at);

  final String regionId;
  final TrailCell cell;
  final GeoPoint position;
  final DateTime at;
}
