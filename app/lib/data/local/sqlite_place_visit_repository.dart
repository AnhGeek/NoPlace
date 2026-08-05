import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/async/replay_subject.dart';
import '../../domain/entities/place_visit.dart';
import '../../domain/repositories/repositories.dart';
import 'app_database.dart';

/// How often the player has been to each of the world's own places, on the
/// device.
///
/// The counterpart to [SqliteMapPointRepository] for places nobody authored:
/// Chợ Bến Thành is not the player's content, but *having been there seven
/// times* is, and it has to survive a restart the same way a dropped pin does.
///
/// Held as a map rather than a list because every read is by id — the check-in
/// sheet asks about one place, the map asks about the handful on screen — and a
/// linear scan of a year of check-ins on every frame is the wrong shape.
class SqlitePlaceVisitRepository implements PlaceVisitRepository {
  SqlitePlaceVisitRepository(this._database);

  final AppDatabase _database;

  final ReplaySubject<Map<String, PlaceVisit>> _visits = ReplaySubject(
    const {},
  );
  bool _loaded = false;

  @override
  Stream<Map<String, PlaceVisit>> watch() => _visits.stream;

  Map<String, PlaceVisit> get current => _visits.value;

  /// The record for [placeId], or an empty one. Never null: "nobody has been
  /// here" is a real answer and every caller would otherwise have to invent it.
  @override
  PlaceVisit of(String placeId) =>
      _visits.value[placeId] ?? PlaceVisit.none(placeId);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    await _reload();
  }

  /// Reads the table again, for when something outside this store has written
  /// to it — which today means a restored backup.
  Future<void> reload() async {
    _loaded = true;
    await _reload();
  }

  Future<void> _reload() async {
    try {
      final db = await _database.open();
      final rows = await db.query('place_visits');
      _visits.value = {
        for (final row in rows) row['place_id']! as String: _fromRow(row),
      };
    } on Object catch (error) {
      debugPrint('Place visits: could not be read ($error)');
    }
  }

  @override
  Future<void> save(PlaceVisit visit) async {
    // In memory first. The write is a round trip to disk and the sheet showing
    // the count is on screen now; a check-in that takes a frame to appear reads
    // as a button that did not work.
    _visits.value = {..._visits.value, visit.placeId: visit};

    final db = await _database.open();
    await db.insert(
      'place_visits',
      _toRow(visit),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Map<String, Object?> _toRow(PlaceVisit visit) => {
    'place_id': visit.placeId,
    'check_in_count': visit.checkInCount,
    'last_check_in_at': visit.lastCheckInAt?.millisecondsSinceEpoch,
    'claimed_at': visit.claimedAt?.millisecondsSinceEpoch,
    'stay_started_at': visit.stayStartedAt?.millisecondsSinceEpoch,
    'stay_last_seen_at': visit.stayLastSeenAt?.millisecondsSinceEpoch,
  };

  static PlaceVisit _fromRow(Map<String, Object?> row) => PlaceVisit(
    placeId: row['place_id']! as String,
    // Clamped at zero rather than trusted: the file is deliberately open to
    // inspection (see [AppDatabase]), and a negative count would print as
    // "checked in -3 times".
    checkInCount: ((row['check_in_count'] as int?) ?? 0).clamp(0, 1 << 31),
    lastCheckInAt: _time(row['last_check_in_at']),
    claimedAt: _time(row['claimed_at']),
    stayStartedAt: _time(row['stay_started_at']),
    stayLastSeenAt: _time(row['stay_last_seen_at']),
  );

  static DateTime? _time(Object? millis) =>
      millis is int ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
}
