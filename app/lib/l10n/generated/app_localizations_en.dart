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
  String get commonGotIt => 'Got it';

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
  String get settingsBackupTitle => 'Backup';

  @override
  String get settingsBackupSubtitle => 'Save your fog and places to a file';

  @override
  String get backupIntro =>
      'Everywhere you have walked lives on this phone only. A backup is one file you can keep anywhere and put back on any phone.';

  @override
  String get backupHolds => 'In the backup';

  @override
  String backupFogCells(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count m² of fog uncovered',
      one: '1 m² of fog uncovered',
      zero: 'No fog uncovered yet',
    );
    return '$_temp0';
  }

  @override
  String backupPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points of your own',
      one: '1 point of your own',
      zero: 'No points of your own',
    );
    return '$_temp0';
  }

  @override
  String backupRegions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cities',
      one: '1 city',
      zero: 'No city walked yet',
    );
    return '$_temp0';
  }

  @override
  String get backupPhotosNote =>
      'Photos stay on this phone. A restored photo point keeps its place and name, and draws as a plain pin.';

  @override
  String get backupSaveAction => 'Save a backup';

  @override
  String get backupRestoreAction => 'Restore from a backup';

  @override
  String get backupRestoreNote =>
      'Restoring adds to what is already here. Nothing you have walked since is lost.';

  @override
  String get backupSaved => 'Backup saved';

  @override
  String backupRestored(int fog, int points) {
    return 'Restored $fog m² of fog and $points points';
  }

  @override
  String get backupFailedSave => 'The backup could not be saved.';

  @override
  String get backupFailedNotABackup => 'That file is not a NoPlace backup.';

  @override
  String get backupFailedTooNew =>
      'That backup was made by a newer version of NoPlace.';

  @override
  String get backupFailedRestore => 'The backup could not be restored.';

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

  @override
  String get mapHideFog => 'Hide the fog';

  @override
  String get mapShowFog => 'Show the fog';

  @override
  String regionArrivedTitle(String region) {
    return 'You\'ve reached $region';
  }

  @override
  String get regionArrivedBody =>
      'The map has switched to this region\'s streets, and to the fog you\'ve lifted here. Every city keeps its own walk.';

  @override
  String get regionPickerLabel => 'Which map to walk with';

  @override
  String get regionPackOnDevice => 'On this phone · works offline';

  @override
  String get regionPackNotDownloaded => 'Not on this phone yet';

  @override
  String get regionArrivedAction => 'Walk here';

  @override
  String get placeUnnamed => 'Unnamed place';

  @override
  String get placeAddTitle => 'New place';

  @override
  String get placeAddAction => 'Save this place';

  @override
  String get placeAddHere => 'Save a place here';

  @override
  String get placeNameHint => 'What do you call it?';

  @override
  String get placeSectionIcon => 'PICK AN ICON';

  @override
  String get placeSectionMood => 'HOW DID IT FEEL?';

  @override
  String get placeSectionRating => 'YOUR RATING';

  @override
  String get placeMoodLove => 'Love it';

  @override
  String get placeMoodHappy => 'Happy';

  @override
  String get placeMoodCalm => 'Calm';

  @override
  String get placeMoodMeh => 'Meh';

  @override
  String get placeMoodBad => 'Not for me';

  @override
  String placeStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stars',
      one: '1 star',
      zero: 'Not rated yet',
    );
    return '$_temp0';
  }

  @override
  String get placeSave => 'Save changes';

  @override
  String get placeCheckInAction => 'I\'m here now';

  @override
  String placeCheckInCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Checked in $count times',
      one: 'Checked in once',
      zero: 'No check-ins yet',
    );
    return '$_temp0';
  }

  @override
  String placeLastCheckIn(String weekday, String time) {
    return 'Last time $weekday at $time';
  }

  @override
  String get placeSectionAutoCheckIn => 'AUTO CHECK-IN';

  @override
  String get placeAutoCheckInOff => 'Off';

  @override
  String get placeAutoCheckInHalfHourly => '30 min';

  @override
  String get placeAutoCheckInHourly => '1 hour';

  @override
  String get placeAutoCheckInTwoHourly => '2 hours';

  @override
  String get placeAutoCheckInSummaryOff =>
      'Only the button counts here — nothing is recorded on its own.';

  @override
  String get placeAutoCheckInSummaryHalfHourly =>
      'Half an hour spent here counts as a check-in on its own.';

  @override
  String get placeAutoCheckInSummaryHourly =>
      'An hour spent here counts as a check-in on its own.';

  @override
  String get placeAutoCheckInSummaryTwoHourly =>
      'Two hours spent here count as a check-in on their own.';

  @override
  String get placeAutoCheckInHelp => 'What does this do?';

  @override
  String get placeAutoCheckInTipTitle => 'Counting your visits for you';

  @override
  String get placeAutoCheckInTipBody =>
      'Stay within 150 m of this place and NoPlace records a visit for you, every time the interval you picked goes by. No tapping, and it keeps counting with the app in your pocket.\n\nIt waits 20 minutes without a sign of you before deciding you have left, so a wandering GPS signal can\'t cut a visit short. Leaving and coming back starts the clock again.\n\nPick Off for somewhere you\'re always at, like home — otherwise it would collect a visit every night.';

  @override
  String placeCheckedIn(String name) {
    return 'Checked in at $name';
  }

  @override
  String placeSaved(String name) {
    return '$name saved';
  }

  @override
  String get placeDelete => 'Delete this place';

  @override
  String placeDeleted(String name) {
    return '$name deleted';
  }

  @override
  String get placeUndo => 'Undo';
}
