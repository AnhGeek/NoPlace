// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'NoPlace';

  @override
  String get navMap => 'Map';

  @override
  String get navLogs => 'Logs';

  @override
  String get navQuests => 'Quests';

  @override
  String get navProfile => 'Profile';

  @override
  String get commonLocked => 'Locked';

  @override
  String get commonHidden => '???';

  @override
  String get commonNotNow => 'Not now';

  @override
  String get commonSearch => 'Search';

  @override
  String commonXp(int xp) {
    return '+$xp XP';
  }

  @override
  String commonDistanceMeters(int meters) {
    return '$meters m';
  }

  @override
  String commonDistanceKilometers(String kilometers) {
    return '$kilometers km';
  }

  @override
  String commonDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get mapTabCity => 'CITY';

  @override
  String get mapTabNearby => 'NEARBY';

  @override
  String get mapSearchHint => 'Search places…';

  @override
  String mapYouAreHere(String place) {
    return 'You are here · $place';
  }

  @override
  String mapNearbyTitle(String place) {
    return 'You\'re near $place';
  }

  @override
  String mapNearbyMeta(String distance, String visited, int xp) {
    String _temp0 = intl.Intl.selectLogic(visited, {
      'never': 'never visited',
      'other': 'visited before',
    });
    return '$distance away · $_temp0 · +$xp XP';
  }

  @override
  String mapNearbyVisitedName(String place) {
    return '$place · checked in';
  }

  @override
  String get mapNearbyWrongPlace => 'Wrong place? Tap to change ›';

  @override
  String get mapCheckIn => 'Check in';

  @override
  String get logsTitle => 'Explorer Logs';

  @override
  String logsDistrictCount(int charted, int total) {
    return '$charted / $total districts';
  }

  @override
  String get logsSegmentDistricts => 'Districts';

  @override
  String get logsSegmentQuests => 'Quests';

  @override
  String logsEntryDistrictCharted(String day, int percent) {
    return 'First entered $day · $percent% charted';
  }

  @override
  String logsEntryCheckedInToday(String time) {
    return 'Checked in today, $time';
  }

  @override
  String logsEntryWithinQuestRadius(String distance) {
    return '$distance away · within quest radius';
  }

  @override
  String get logsEntryLocked => 'Locked · travel there to reveal';

  @override
  String get logsUnknownSite => 'Unknown site';

  @override
  String get logsEmpty =>
      'Nothing logged yet. Step outside and the map will fill in.';

  @override
  String get questsTitle => 'Quests';

  @override
  String questsActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active',
      one: '1 active',
    );
    return '$_temp0';
  }

  @override
  String get questsWeeklyChallenge => 'Weekly challenge';

  @override
  String questsWeeklyChallengeGoal(int target, int done) {
    return 'Reveal $target unknown sites · $done/$target done';
  }

  @override
  String get questsRevealSiteTitle => 'Reveal the unknown site';

  @override
  String questsRevealSiteSubtitle(String distance, String district) {
    return '$distance away · $district';
  }

  @override
  String questsWalkTitle(String target) {
    return 'Walk $target km today';
  }

  @override
  String questsWalkSubtitle(String done, String target) {
    return '$done / $target km';
  }

  @override
  String get questsNewDistrictTitle => 'Enter a new district';

  @override
  String questsNewDistrictSubtitle(String district, String distance) {
    return 'Nearest: $district · $distance';
  }

  @override
  String get questsNightWandererTitle => 'Night wanderer';

  @override
  String questsUnlocksAtLevel(int level) {
    return 'Unlocks at level $level';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String profileLevelLine(int level, int xp) {
    return 'Level $level Explorer · $xp XP';
  }

  @override
  String profileChartedShare(int percent) {
    return '$percent%';
  }

  @override
  String get profileChartedCaption => 'of the city charted';

  @override
  String get profileStatDistanceToday => 'Distance today';

  @override
  String get profileStatCheckIns => 'Check-in places';

  @override
  String get profileStatStreak => 'Active streak';

  @override
  String profileCityCurrent(String city) {
    return '$city · current';
  }

  @override
  String get profileAddCity => '+ Add city';

  @override
  String profileCityProgressTitle(String city) {
    return 'City progress · $city';
  }

  @override
  String get profileRankingTitle => 'City ranking';

  @override
  String profileRankingSubtitle(int rank, int total) {
    return 'You\'re #$rank of $total explorers';
  }

  @override
  String profileRankingTrend(int percent) {
    return '+$percent%';
  }

  @override
  String checkInSheetMeta(String category, String distance, String visited) {
    String _temp0 = intl.Intl.selectLogic(visited, {
      'never': 'never visited',
      'other': 'visited before',
    });
    return '$category · $distance away · $_temp0';
  }

  @override
  String get checkInExplorersHere => 'explorers here';

  @override
  String get checkInFirstVisit => 'First';

  @override
  String get checkInFirstVisitBonus => 'visit bonus ×2';

  @override
  String get checkInStreakKept => 'streak kept';

  @override
  String get checkInAction => 'Check in here';

  @override
  String get checkInWrongPlaceTitle => 'Not this place? Pick the right one';

  @override
  String checkInSuccess(String place) {
    return 'Checked in at $place';
  }

  @override
  String get checkInTooFar => 'You\'re too far away to check in here.';

  @override
  String get checkInFailed => 'That didn\'t work. Try again in a moment.';

  @override
  String get discoveryKicker => 'NEW DISTRICT DISCOVERED';

  @override
  String discoveryMeta(int index, int total, String city) {
    return 'District $index of $total · $city';
  }

  @override
  String get discoveryAction => 'Start exploring';

  @override
  String get settingsMapLayers => 'Points on the map';

  @override
  String get settingsShowSuggestedPoints => 'Suggested places';

  @override
  String get settingsShowSuggestedPointsDetail => 'Places we found near you';

  @override
  String get settingsHideUserPoints => 'My points';

  @override
  String get settingsHideUserPointsDetail => 'Pins you dropped yourself';

  @override
  String get settingsHidePicturePoints => 'Photo points';

  @override
  String get settingsHidePicturePointsDetail => 'Places you photographed';

  @override
  String get settingsNearby => 'Nearby';

  @override
  String get settingsNearbyRadius => 'How far to look';

  @override
  String get settingsNearbyRadiusDetail =>
      'Places within this distance show up in NEARBY';

  @override
  String get settingsFogTitle => 'Fog';

  @override
  String get settingsFogSubtitle => 'How much walking uncovers';

  @override
  String get settingsFogClearingRadius => 'Clearing size';

  @override
  String get settingsFogClearingRadiusDetail =>
      'How far you can see from where you stand';

  @override
  String get settingsFogPrecision => 'Recording precision';

  @override
  String get settingsFogPrecisionDetail =>
      'Finer keeps a truer trail and a bigger file';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsDesignGallery => 'Design system gallery';

  @override
  String get locationServiceOffTitle => 'Location is switched off';

  @override
  String get locationServiceOffBody =>
      'NoPlace cannot uncover the map without it.';

  @override
  String get locationDeniedTitle => 'NoPlace needs your location';

  @override
  String get locationDeniedBody =>
      'Walking is what uncovers the map, so we need to know where you are.';

  @override
  String get locationDeniedForeverTitle => 'Location is blocked';

  @override
  String get locationDeniedForeverBody =>
      'Turn it back on in Settings to keep uncovering the map.';

  @override
  String get locationActionTurnOn => 'Turn on';

  @override
  String get locationActionAllow => 'Allow';

  @override
  String get locationActionSettings => 'Open settings';

  @override
  String get locationWaiting => 'Looking for you…';

  @override
  String get backgroundAskTitle => 'Keep recording while you walk';

  @override
  String get backgroundAskBody =>
      'NoPlace uncovers the map from where you actually go — which means recording with the screen off and the phone in your pocket. Battery saving stops that unless you allow it, and the walk comes back with gaps.';

  @override
  String get backgroundAskNote =>
      'A notification is showing the whole time it records. Nothing happens while NoPlace is closed.';

  @override
  String get backgroundAskAction => 'Allow';

  @override
  String get backgroundSleepTitle => 'Your phone can pause NoPlace';

  @override
  String get backgroundSleepBody =>
      'Battery saving is allowed to put the app to sleep in your pocket, which leaves gaps in the walk.';

  @override
  String get backgroundSleepAction => 'Keep awake';

  @override
  String mapNearestTitle(String place) {
    return 'Nearest · $place';
  }

  @override
  String mapNearestMeta(Object distance) {
    return '$distance away · walk closer to check in';
  }

  @override
  String get mapNothingNearbyTitle => 'Nothing mapped here yet';

  @override
  String get mapNothingNearbyBody =>
      'Keep walking — the map still opens as you go.';

  @override
  String get mapRecentre => 'Centre on me';
}
