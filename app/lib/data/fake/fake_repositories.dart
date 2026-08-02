import '../../domain/entities/check_in.dart';
import '../../domain/entities/district.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/log_entry.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/quest.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/rules/exploration_rules.dart';
import 'fake_world_store.dart';

/// Repository implementations backed by [FakeWorldStore].
///
/// They are thin on purpose: all the rules live in the store, so the day a
/// remote implementation arrives it can be compared against these line by line.

class FakeWorldRepository implements WorldRepository {
  const FakeWorldRepository(this._store);

  final FakeWorldStore _store;

  @override
  Stream<City> watchCurrentCity() => _store.city;

  @override
  Stream<List<District>> watchDistricts() => _store.districts;

  @override
  Stream<List<Place>> watchPlaces() => _store.places;

  @override
  Stream<GeoPoint> watchPlayerPosition() => _store.position;

  /// Recomputed when the **player moves**, not when the place list changes.
  ///
  /// It used to key off `places`, which is emitted once and never again — so
  /// with a fixed seed position it looked right and with a real GPS it froze
  /// the nearby list at wherever the app started. Places are static in the fake
  /// world; the position is the thing that moves.
  @override
  Stream<List<Place>> watchNearbyPlaces({
    double radiusMeters = ExplorationRules.defaultNearbyRadiusMeters,
  }) => _store.position.map((_) => _store.nearbyPlaces(radiusMeters));
}

class FakePlayerRepository implements PlayerRepository {
  const FakePlayerRepository(this._store);

  final FakeWorldStore _store;

  @override
  Stream<Player> watchPlayer() => _store.player;
}

class FakeLogRepository implements LogRepository {
  const FakeLogRepository(this._store);

  final FakeWorldStore _store;

  @override
  Stream<List<LogEntry>> watchEntries() => _store.logs;
}

class FakeQuestRepository implements QuestRepository {
  const FakeQuestRepository(this._store);

  final FakeWorldStore _store;

  @override
  Stream<List<Quest>> watchQuests() => _store.quests;

  @override
  Stream<WeeklyChallenge> watchWeeklyChallenge() => _store.weeklyChallenge;
}

class FakeCheckInRepository implements CheckInRepository {
  const FakeCheckInRepository(this._store);

  final FakeWorldStore _store;

  @override
  Future<CheckInResult> checkIn(String placeId) async {
    // A real check-in is a network round trip; the delay keeps the button's
    // pending state honest instead of flashing past in one frame.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    return _store.checkIn(placeId);
  }
}
