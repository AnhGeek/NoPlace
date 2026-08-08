import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/async/replay_subject.dart';
import '../../domain/entities/fog_settings.dart';
import '../../domain/entities/geo_point.dart';
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
  static const String _fogVisibleKey = 'map.show_fog';
  static const String _clearingRadiusKey = 'fog.clearing_radius_meters';
  static const String _precisionKey = 'fog.recording_precision_meters';
  static const String _nearbyRadiusKey = 'nearby.radius_meters';
  static const String _backgroundPromptKey = 'background.prompt_seen';
  static const String _lastFixKey = 'location.last_fix';
  static const String _displayNameKey = 'profile.display_name';
  static const String _avatarPathKey = 'profile.avatar_path';

  /// Empty until the player names themselves. The profile shows its own
  /// placeholder for that, translated — a default written here would be in
  /// whatever language the developer happened to think in.
  final ReplaySubject<String> _displayName = ReplaySubject('');

  final ReplaySubject<String?> _avatarPath = ReplaySubject(null);

  /// Asked once, then never again — see [PreferencesRepository].
  final ReplaySubject<bool> _backgroundPromptSeen = ReplaySubject(false);

  /// Where the player was standing the last time the app worked out which
  /// city they were in — see [PreferencesRepository.lastFix]. A plain field
  /// rather than a subject: nothing on screen renders it.
  GeoPoint? _lastFix;

  @override
  Stream<String> watchDisplayName() => _displayName.stream;

  @override
  Stream<String?> watchAvatarPath() => _avatarPath.stream;

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

  @override
  GeoPoint? get lastFix => _lastFix;

  /// Written on a region resolution rather than on every fix: the question it
  /// answers is which city, and a walk across town is thousands of fixes and
  /// one answer.
  @override
  Future<void> saveLastFix(GeoPoint position) async {
    if (_lastFix == position) return;
    _lastFix = position;
    await _write(_lastFixKey, '${position.latitude},${position.longitude}');
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    await _read();
  }

  /// Reads the table again, for when something outside this store has written
  /// to it — which today means a restored backup.
  Future<void> reload() async {
    _loaded = true;
    await _read();
  }

  Future<void> _read() async {
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
        showFog: read(_fogVisibleKey),
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

      _displayName.value = values[_displayNameKey] ?? '';

      // An empty row is a picture the player removed, which is a different
      // answer from never having chosen one — but both draw the placeholder, so
      // both arrive here as null.
      final avatar = values[_avatarPathKey];
      _avatarPath.value = (avatar == null || avatar.isEmpty) ? null : avatar;

      _lastFix = _parseFix(values[_lastFixKey]);
    } on Object catch (error) {
      // Falling back to "show everything" is the safe default: a preference we
      // cannot read must never hide the player's own points.
      debugPrint('Preferences: could not be read ($error)');
    }
  }

  /// Trimmed and capped, because this is drawn in one line under an avatar and
  /// the player is the only person who will ever read it — there is nobody to
  /// impersonate and nothing to validate against.
  @override
  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    final capped = trimmed.length > maxDisplayNameLength
        ? trimmed.substring(0, maxDisplayNameLength)
        : trimmed;

    if (_displayName.value == capped) return;
    _displayName.value = capped;
    await _write(_displayNameKey, capped);
  }

  /// Null clears the picture, which is a thing the player is allowed to want.
  @override
  Future<void> setAvatarPath(String? path) async {
    if (_avatarPath.value == path) return;
    _avatarPath.value = path;
    await _write(_avatarPathKey, path ?? '');
  }

  static const int maxDisplayNameLength = 24;

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

  /// `"10.7725,106.698"`, or null for anything else.
  ///
  /// Anything else includes a row written by a build that stored something
  /// different here, and a latitude that has since become out of range — the
  /// [GeoPoint] assertion would otherwise take the whole preferences read down
  /// with it and leave the player looking at default settings.
  static GeoPoint? _parseFix(String? value) {
    if (value == null) return null;

    final parts = value.split(',');
    if (parts.length != 2) return null;

    final latitude = double.tryParse(parts.first);
    final longitude = double.tryParse(parts.last);
    if (latitude == null || longitude == null) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;

    return GeoPoint(latitude, longitude);
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

  @override
  Future<void> setFogVisible({required bool visible}) async {
    _visibility.value = _visibility.value.withFog(visible: visible);
    await _write(_fogVisibleKey, visible.toString());
  }
}
