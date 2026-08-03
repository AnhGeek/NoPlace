import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/async/replay_subject.dart';
import '../../domain/entities/fog_settings.dart';
import '../../domain/entities/map_layer_visibility.dart';
import '../../domain/entities/map_point.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/rules/exploration_rules.dart';
import 'app_database.dart';

/// Small settings, in the same database as everything else.
///
/// A key/value table rather than a second storage plugin: one file to back up,
/// one file to inspect, one thing to get right.
class SqlitePreferencesRepository implements PreferencesRepository {
  SqlitePreferencesRepository(this._database);

  final AppDatabase _database;

  final ReplaySubject<MapLayerVisibility> _visibility = ReplaySubject(
    const MapLayerVisibility(),
  );
  bool _loaded = false;

  final ReplaySubject<FogSettings> _fog = ReplaySubject(const FogSettings());

  final ReplaySubject<double> _nearbyRadius = ReplaySubject(
    ExplorationRules.defaultNearbyRadiusMeters,
  );

  static const String _suggestedKey = 'map.show_suggested_points';
  static const String _userKey = 'map.show_user_points';
  static const String _pictureKey = 'map.show_picture_points';
  static const String _clearingRadiusKey = 'fog.clearing_radius_meters';
  static const String _precisionKey = 'fog.recording_precision_meters';
  static const String _nearbyRadiusKey = 'nearby.radius_meters';
  static const String _backgroundPromptKey = 'background.prompt_seen';

  /// Asked once, then never again — see [PreferencesRepository].
  final ReplaySubject<bool> _backgroundPromptSeen = ReplaySubject(false);

  @override
  Stream<MapLayerVisibility> watchMapLayerVisibility() => _visibility.stream;

  @override
  Stream<FogSettings> watchFogSettings() => _fog.stream;

  @override
  Stream<double> watchNearbyRadiusMeters() => _nearbyRadius.stream;

  @override
  Stream<bool> watchBackgroundPromptSeen() => _backgroundPromptSeen.stream;

  MapLayerVisibility get currentVisibility => _visibility.value;

  FogSettings get currentFogSettings => _fog.value;

  double get currentNearbyRadiusMeters => _nearbyRadius.value;

  bool get currentBackgroundPromptSeen => _backgroundPromptSeen.value;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final db = await _database.open();
      final rows = await db.query('preferences');
      final values = {
        for (final row in rows) row['key']! as String: row['value']! as String,
      };

      bool read(String key) => values[key] != 'false';

      _visibility.value = MapLayerVisibility(
        showSuggested: read(_suggestedKey),
        showUser: read(_userKey),
        showPictures: read(_pictureKey),
      );

      const defaults = FogSettings();
      _fog.value = FogSettings(
        clearingRadiusMeters:
            double.tryParse(values[_clearingRadiusKey] ?? '') ??
            defaults.clearingRadiusMeters,
        recordingPrecisionMeters:
            double.tryParse(values[_precisionKey] ?? '') ??
            defaults.recordingPrecisionMeters,
      );

      _nearbyRadius.value =
          double.tryParse(values[_nearbyRadiusKey] ?? '') ??
          ExplorationRules.defaultNearbyRadiusMeters;

      // Absent means "not asked yet", which is the one case that shows the
      // dialog — so this cannot use `read()`, whose default is true.
      _backgroundPromptSeen.value = values[_backgroundPromptKey] == 'true';
    } on Object catch (error) {
      // Falling back to "show everything" is the safe default: a preference we
      // cannot read must never hide the player's own points.
      debugPrint('Preferences: could not be read ($error)');
    }
  }

  @override
  Future<void> setFogSettings(FogSettings settings) async {
    _fog.value = settings;
    await _write(_clearingRadiusKey, '${settings.clearingRadiusMeters}');
    await _write(_precisionKey, '${settings.recordingPrecisionMeters}');
  }

  @override
  Future<void> setNearbyRadiusMeters(double meters) async {
    _nearbyRadius.value = meters;
    await _write(_nearbyRadiusKey, '$meters');
  }

  @override
  Future<void> markBackgroundPromptSeen() async {
    if (_backgroundPromptSeen.value) return;
    _backgroundPromptSeen.value = true;
    await _write(_backgroundPromptKey, 'true');
  }

  Future<void> _write(String key, String value) async {
    try {
      final db = await _database.open();
      await db.insert('preferences', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } on Object catch (error) {
      debugPrint('Preferences: could not be saved ($error)');
    }
  }

  @override
  Future<void> setMapLayerVisible(
    MapPointKind kind, {
    required bool visible,
  }) async {
    _visibility.value = _visibility.value.withKind(kind, visible: visible);

    final key = switch (kind) {
      MapPointKind.suggested => _suggestedKey,
      MapPointKind.user => _userKey,
      MapPointKind.picture => _pictureKey,
    };

    await _write(key, visible.toString());
  }
}
