import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/async/replay_subject.dart';
import '../../domain/entities/auto_check_in.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/map_point.dart';
import '../../domain/repositories/repositories.dart';
import 'app_database.dart';

/// The player's own points — dropped pins and photo points — in SQLite.
class SqliteMapPointRepository implements MapPointRepository {
  SqliteMapPointRepository(this._database);

  final AppDatabase _database;

  final ReplaySubject<List<MapPoint>> _points = ReplaySubject(const []);
  bool _loaded = false;

  @override
  Stream<List<MapPoint>> watch() => _points.stream;

  List<MapPoint> get current => _points.value;

  @override
  MapPoint? of(String id) {
    for (final point in _points.value) {
      if (point.id == id) return point;
    }
    return null;
  }

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
      final rows = await db.query('map_points', orderBy: 'created_at DESC');
      _points.value = rows.map(_fromRow).toList();
    } on Object catch (error) {
      debugPrint('Map points: could not be read ($error)');
    }
  }

  @override
  Future<void> add(MapPoint point) async {
    final db = await _database.open();
    await db.insert('map_points', _toRow(point));
    _points.value = [point, ..._points.value];
  }

  @override
  Future<void> remove(String id) async {
    final db = await _database.open();
    await db.delete('map_points', where: 'id = ?', whereArgs: [id]);
    _points.value = _points.value
        .where((point) => point.id != id)
        .toList(growable: false);
  }

  @override
  Future<void> update(MapPoint point) async {
    final db = await _database.open();
    await db.update(
      'map_points',
      _toRow(point),
      where: 'id = ?',
      whereArgs: [point.id],
    );
    _points.value = [
      for (final existing in _points.value)
        if (existing.id == point.id) point else existing,
    ];
  }

  /// Writes [points] only if the table is empty.
  ///
  /// Used to put something on the map before the capture and pin-dropping flows
  /// exist. It is a one-shot: once the player has authored anything, this never
  /// touches their data again.
  Future<void> seedIfEmpty(List<MapPoint> points) async {
    if (_points.value.isNotEmpty) return;

    final db = await _database.open();
    final batch = db.batch();
    for (final point in points) {
      batch.insert('map_points', _toRow(point));
    }
    await batch.commit(noResult: true);
    await _reload();
  }

  static Map<String, Object?> _toRow(MapPoint point) => {
    'id': point.id,
    'kind': point.kind.name,
    'latitude': point.location.latitude,
    'longitude': point.location.longitude,
    'label': point.label,
    'icon_id': point.iconId,
    'image_path': point.imagePath,
    'created_at': point.createdAt.millisecondsSinceEpoch,
    'stars': point.stars,
    'mood': point.moodId,
    'check_in_count': point.checkInCount,
    'last_check_in_at': point.lastCheckInAt?.millisecondsSinceEpoch,
    'stay_started_at': point.stayStartedAt?.millisecondsSinceEpoch,
    'stay_last_seen_at': point.stayLastSeenAt?.millisecondsSinceEpoch,
    'auto_check_in_minutes': AutoCheckIn.toMinutes(point.autoCheckInEvery),
  };

  static MapPoint _fromRow(Map<String, Object?> row) => MapPoint(
    id: row['id']! as String,
    kind: MapPointKind.values.firstWhere(
      (kind) => kind.name == row['kind'],
      // A row written by a newer build with a kind we do not know is shown as a
      // plain user point rather than crashing the map.
      orElse: () => MapPointKind.user,
    ),
    location: GeoPoint(row['latitude']! as double, row['longitude']! as double),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    label: row['label'] as String? ?? '',
    iconId: row['icon_id'] as String? ?? MapPointIcon.defaultId,
    imagePath: row['image_path'] as String?,
    // Clamped rather than trusted: the file is deliberately open to inspection
    // (see [AppDatabase]), so a hand-edited row must not be able to assert an
    // eight-star café past the entity's own bounds check.
    stars: ((row['stars'] as int?) ?? 0).clamp(0, MapPoint.maxStars),
    moodId: row['mood'] as String? ?? PlaceMood.none,
    checkInCount: (row['check_in_count'] as int?) ?? 0,
    lastCheckInAt: _time(row['last_check_in_at']),
    stayStartedAt: _time(row['stay_started_at']),
    stayLastSeenAt: _time(row['stay_last_seen_at']),
    autoCheckInEvery: AutoCheckIn.fromMinutes(row['auto_check_in_minutes']),
  );

  static DateTime? _time(Object? millis) =>
      millis is int ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
}
