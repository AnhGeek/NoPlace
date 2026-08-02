import '../../core/async/replay_subject.dart';
import '../../domain/entities/check_in.dart';
import '../../domain/entities/district.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/log_entry.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/quest.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/rules/exploration_rules.dart';

/// The whole game world, in memory.
///
/// This exists so the UI can be built, reviewed and demoed before a single
/// endpoint is written. It is a *fake*, not a mock: it holds real state and
/// applies the real rules (first visit doubles the XP, entering a district the
/// first time triggers a discovery), so the screens are exercised the way they
/// will be in production.
///
/// When the backend lands, the repository implementations in `lib/data/remote/`
/// replace the fake ones in `repository_providers.dart`. Nothing above this
/// layer changes.
class FakeWorldStore {
  FakeWorldStore() {
    final now = DateTime.now();
    final today9am = DateTime(now.year, now.month, now.day, 9, 12);
    final lastTuesday = now.subtract(const Duration(days: 4));

    _city = ReplaySubject(_seedCity);
    _position = ReplaySubject(_seedPosition);
    _places = ReplaySubject(_seedPlaces);
    _districts = ReplaySubject(_seedDistricts(lastTuesday));
    _player = ReplaySubject(_seedPlayer);
    _logs = ReplaySubject([
      DistrictLogEntry(
        id: 'log-district-1',
        at: lastTuesday,
        districtName: 'District 1',
        chartedFraction: 0.38,
        xpAwarded: 100,
      ),
      CheckInLogEntry(
        id: 'log-post-office',
        at: today9am,
        placeName: 'Saigon Post Office',
        xpAwarded: 50,
      ),
      UnknownSiteLogEntry(
        id: 'log-unknown-site',
        at: today9am.subtract(const Duration(hours: 1)),
        distanceMeters: 480,
        xpAwarded: 50,
      ),
      LockedLogEntry(
        id: 'log-locked-1',
        at: today9am.subtract(const Duration(hours: 2)),
      ),
      LockedLogEntry(
        id: 'log-locked-2',
        at: today9am.subtract(const Duration(hours: 3)),
      ),
    ]);
    _quests = ReplaySubject(const [
      RevealSiteQuest(
        id: 'quest-reveal',
        xpReward: 50,
        distanceMeters: 480,
        districtName: 'District 1',
      ),
      WalkDistanceQuest(
        id: 'quest-walk',
        xpReward: 30,
        targetMeters: 5000,
        doneMeters: 4200,
      ),
      EnterDistrictQuest(
        id: 'quest-district',
        xpReward: 100,
        nearestDistrictName: 'Bình Thạnh',
        distanceMeters: 1800,
      ),
      LockedQuest(
        id: 'quest-night',
        teaser: LockedQuestTeaser.nightWanderer,
        unlockLevel: 5,
      ),
    ]);
    _weeklyChallenge = ReplaySubject(
      const WeeklyChallenge(target: 3, done: 2, xpReward: 300),
    );
  }

  // --- Seed ---------------------------------------------------------------

  static const _seedPosition = GeoPoint(10.7725, 106.6980);

  static const _seedCity = City(
    id: 'city-hcmc',
    name: 'TP.HCM',
    center: _seedPosition,
    districtCount: 12,
  );

  static const _seedPlayer = Player(
    id: 'player-1',
    displayName: 'Wayfarer_01',
    level: 4,
    xp: 340,
    currentCityId: 'city-hcmc',
    chartedFraction: 0.38,
    distanceTodayMeters: 4200,
    checkInPlaces: 27,
    streakDays: 6,
    cityRank: 125,
    cityExplorers: 430,
    rankTrendPercent: 14,
  );

  static const List<Place> _seedPlaces = [
    Place(
      id: 'place-ben-thanh',
      name: 'Chợ Bến Thành',
      category: PlaceCategory.market,
      location: GeoPoint(10.77286, 106.69800),
      districtId: 'district-1',
      explorersHere: 12,
    ),
    Place(
      id: 'place-pho-hoa',
      name: 'Phở Hòa Pasteur',
      category: PlaceCategory.food,
      location: GeoPoint(10.77201, 106.69838),
      districtId: 'district-1',
      explorersHere: 4,
    ),
    Place(
      id: 'place-notre-dame',
      name: 'Nhà thờ Đức Bà',
      category: PlaceCategory.landmark,
      location: GeoPoint(10.77313, 106.69852),
      districtId: 'district-1',
      explorersHere: 31,
    ),
    Place(
      id: 'place-post-office',
      name: 'Saigon Post Office',
      category: PlaceCategory.landmark,
      location: GeoPoint(10.77082, 106.69984),
      districtId: 'district-1',
      visited: true,
      explorersHere: 9,
    ),
    Place(
      id: 'place-coffee-house',
      name: 'The Coffee House',
      category: PlaceCategory.cafe,
      location: GeoPoint(10.77120, 106.69540),
      districtId: 'district-1',
      explorersHere: 6,
    ),
    Place(
      id: 'place-tao-dan',
      name: 'Công viên Tao Đàn',
      category: PlaceCategory.park,
      location: GeoPoint(10.76984, 106.69289),
      districtId: 'district-3',
      explorersHere: 2,
    ),
    Place(
      id: 'place-unknown-1',
      name: '',
      category: PlaceCategory.unknown,
      location: GeoPoint(10.77600, 106.69550),
      districtId: 'district-1',
    ),

    // Outside District 1, so there is somewhere to walk that is not the centre
    // of town. Coordinates come from OpenStreetMap — the same source as the
    // basemap, so a pin sits on the building rather than near it.
    Place(
      id: 'place-lotte-go-vap',
      name: 'Lotte Mart Gò Vấp',
      category: PlaceCategory.market,
      location: GeoPoint(10.83792, 106.67133),
      districtId: 'district-go-vap',
      explorersHere: 7,
    ),
    Place(
      id: 'place-vincom-go-vap',
      name: 'Vincom Plaza Gò Vấp',
      category: PlaceCategory.market,
      location: GeoPoint(10.82695, 106.68924),
      districtId: 'district-go-vap',
      explorersHere: 11,
    ),
    Place(
      id: 'place-gia-dinh-park',
      name: 'Công viên Gia Định',
      category: PlaceCategory.park,
      location: GeoPoint(10.81247, 106.67444),
      districtId: 'district-go-vap',
      explorersHere: 18,
    ),
    Place(
      id: 'place-aeon-tan-phu',
      name: 'AEON Mall Tân Phú Celadon',
      category: PlaceCategory.market,
      location: GeoPoint(10.80141, 106.61716),
      districtId: 'district-tan-phu',
      explorersHere: 23,
    ),
  ];

  static List<District> _seedDistricts(DateTime lastTuesday) => [
    District(
      id: 'district-1',
      cityId: 'city-hcmc',
      name: 'District 1',
      index: 1,
      center: const GeoPoint(10.7756, 106.7019),
      chartedFraction: 0.62,
      firstEnteredAt: lastTuesday,
    ),
    District(
      id: 'district-3',
      cityId: 'city-hcmc',
      name: 'District 3',
      index: 3,
      center: const GeoPoint(10.7833, 106.6822),
      chartedFraction: 0.24,
      firstEnteredAt: lastTuesday.add(const Duration(days: 1)),
    ),
    const District(
      id: 'district-binh-thanh',
      cityId: 'city-hcmc',
      name: 'Bình Thạnh',
      index: 3,
      center: GeoPoint(10.8039, 106.7077),
      chartedFraction: 0.08,
    ),
    // Undiscovered on purpose: walking to any of the places in them is the
    // first chance to see the district-discovered celebration for real.
    const District(
      id: 'district-go-vap',
      cityId: 'city-hcmc',
      name: 'Gò Vấp',
      index: 5,
      center: GeoPoint(10.8231, 106.6800),
    ),
    const District(
      id: 'district-tan-phu',
      cityId: 'city-hcmc',
      name: 'Tân Phú',
      index: 6,
      center: GeoPoint(10.7913, 106.6280),
    ),
    const District(
      id: 'district-locked-1',
      cityId: 'city-hcmc',
      name: '',
      index: 4,
      center: GeoPoint(10.7626, 106.6822),
    ),
  ];

  // --- State --------------------------------------------------------------

  late final ReplaySubject<City> _city;
  late final ReplaySubject<GeoPoint> _position;
  late final ReplaySubject<List<Place>> _places;
  late final ReplaySubject<List<District>> _districts;
  late final ReplaySubject<Player> _player;
  late final ReplaySubject<List<LogEntry>> _logs;
  late final ReplaySubject<List<Quest>> _quests;
  late final ReplaySubject<WeeklyChallenge> _weeklyChallenge;

  Stream<City> get city => _city.stream;
  Stream<GeoPoint> get position => _position.stream;
  Stream<List<Place>> get places => _places.stream;
  Stream<List<District>> get districts => _districts.stream;
  Stream<Player> get player => _player.stream;
  Stream<List<LogEntry>> get logs => _logs.stream;
  Stream<List<Quest>> get quests => _quests.stream;
  Stream<WeeklyChallenge> get weeklyChallenge => _weeklyChallenge.stream;

  GeoPoint get currentPosition => _position.value;

  /// Moves the player to a real GPS fix.
  ///
  /// The world is still fake — the places and districts are seeded — but *where
  /// the player is* is not, and everything derived from it follows: the nearby
  /// list, the check-in candidate, the distances on the card. Without this the
  /// GPS would move the marker and nothing else, which is worse than no GPS at
  /// all because it looks like it works.
  void moveTo(GeoPoint position) {
    if (_position.value == position) return;
    _position.value = position;
  }

  /// Places within [radiusMeters] of the player, nearest first.
  List<Place> nearbyPlaces(double radiusMeters) {
    final origin = _position.value;
    final withDistance =
        _places.value
            .map((place) => (place, origin.distanceTo(place.location)))
            .where((entry) => entry.$2 <= radiusMeters)
            .toList()
          ..sort((a, b) => a.$2.compareTo(b.$2));
    return withDistance.map((entry) => entry.$1).toList();
  }

  double distanceToPlayer(Place place) =>
      _position.value.distanceTo(place.location);

  // --- Mutations ----------------------------------------------------------

  /// The one rule engine in the fake: awards XP, doubles it on a first visit,
  /// appends a log entry and unlocks the district when it is the first time in.
  CheckInResult checkIn(String placeId) {
    final index = _places.value.indexWhere((place) => place.id == placeId);
    if (index < 0) {
      throw const CheckInFailure(CheckInFailureReason.unknownPlace);
    }

    final place = _places.value[index];
    if (distanceToPlayer(place) > ExplorationRules.checkInRadiusMeters) {
      throw const CheckInFailure(CheckInFailureReason.outOfRange);
    }

    final isFirstVisit = !place.visited;
    final xpAwarded = isFirstVisit
        ? place.xpReward * ExplorationRules.firstVisitMultiplier
        : place.xpReward;
    final now = DateTime.now();

    final places = [..._places.value];
    places[index] = place.copyWith(visited: true);
    _places.value = places;

    final player = _player.value;
    _player.value = player.copyWith(
      xp: player.xp + xpAwarded,
      checkInPlaces: isFirstVisit
          ? player.checkInPlaces + 1
          : player.checkInPlaces,
    );

    _logs.value = [
      CheckInLogEntry(
        id: 'log-${place.id}-${now.millisecondsSinceEpoch}',
        at: now,
        placeName: place.name,
        xpAwarded: xpAwarded,
      ),
      ..._logs.value,
    ];

    return CheckInResult(
      place: places[index],
      xpAwarded: xpAwarded,
      isFirstVisit: isFirstVisit,
      streakDays: _player.value.streakDays,
      districtDiscovered: _discoverDistrictOf(place, now),
    );
  }

  District? _discoverDistrictOf(Place place, DateTime now) {
    final index = _districts.value.indexWhere((d) => d.id == place.districtId);
    if (index < 0) return null;

    final district = _districts.value[index];
    if (district.isDiscovered) return null;

    final districts = [..._districts.value];
    districts[index] = district.copyWith(firstEnteredAt: now);
    _districts.value = districts;

    _logs.value = [
      DistrictLogEntry(
        id: 'log-${district.id}-${now.millisecondsSinceEpoch}',
        at: now,
        districtName: district.name,
        chartedFraction: districts[index].chartedFraction,
        xpAwarded: ExplorationRules.districtDiscoveryXp,
      ),
      ..._logs.value,
    ];

    final player = _player.value;
    _player.value = player.copyWith(
      xp: player.xp + ExplorationRules.districtDiscoveryXp,
    );

    return districts[index];
  }

  /// Debug affordance used by the design gallery to show the discovery screen
  /// without walking across town.
  District? previewNextDiscovery() {
    for (final district in _districts.value) {
      if (!district.isDiscovered && district.name.isNotEmpty) return district;
    }
    return null;
  }
}
