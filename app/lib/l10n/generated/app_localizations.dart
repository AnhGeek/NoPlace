import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// Product name. Never translated.
  ///
  /// In en, this message translates to:
  /// **'NoPlace'**
  String get appName;

  /// Bottom navigation label for the map tab.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// Bottom navigation label for the explorer logs tab.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get navLogs;

  /// Bottom navigation label for the quests tab.
  ///
  /// In en, this message translates to:
  /// **'Quests'**
  String get navQuests;

  /// Bottom navigation label for the player profile tab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Short label on content the player has not unlocked yet.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get commonLocked;

  /// Placeholder shown instead of the name of an undiscovered place.
  ///
  /// In en, this message translates to:
  /// **'???'**
  String get commonHidden;

  /// Dismiss button on a sheet, keeping the action available later.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get commonNotNow;

  /// Generic search action label.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// Experience points a player earns or can earn.
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP'**
  String commonXp(int xp);

  /// A distance below one kilometre.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String commonDistanceMeters(int meters);

  /// A distance of one kilometre or more, already rounded to one decimal.
  ///
  /// In en, this message translates to:
  /// **'{kilometers} km'**
  String commonDistanceKilometers(String kilometers);

  /// A number of days, used by the streak counter.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String commonDays(int count);

  /// Map filter showing the whole city. Displayed in upper case.
  ///
  /// In en, this message translates to:
  /// **'CITY'**
  String get mapTabCity;

  /// Map filter showing only places within walking distance. Upper case.
  ///
  /// In en, this message translates to:
  /// **'NEARBY'**
  String get mapTabNearby;

  /// Placeholder inside the map search field.
  ///
  /// In en, this message translates to:
  /// **'Search places…'**
  String get mapSearchHint;

  /// Chip above the player marker naming the current place.
  ///
  /// In en, this message translates to:
  /// **'You are here · {place}'**
  String mapYouAreHere(String place);

  /// Headline of the card suggesting a check-in.
  ///
  /// In en, this message translates to:
  /// **'You\'\'re near {place}'**
  String mapNearbyTitle(String place);

  /// Supporting line of the nearby card: distance, visit history and reward.
  ///
  /// In en, this message translates to:
  /// **'{distance} away · {visited, select, never{never visited} other{visited before}} · +{xp} XP'**
  String mapNearbyMeta(String distance, String visited, int xp);

  /// Hint letting the player correct the auto-detected place.
  ///
  /// In en, this message translates to:
  /// **'Wrong place? Tap to change ›'**
  String get mapNearbyWrongPlace;

  /// Primary action on the nearby card.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get mapCheckIn;

  /// Title of the logs screen.
  ///
  /// In en, this message translates to:
  /// **'Explorer Logs'**
  String get logsTitle;

  /// How many districts of the current city the player has charted.
  ///
  /// In en, this message translates to:
  /// **'{charted} / {total} districts'**
  String logsDistrictCount(int charted, int total);

  /// Segmented control option listing district entries.
  ///
  /// In en, this message translates to:
  /// **'Districts'**
  String get logsSegmentDistricts;

  /// Segmented control option listing quest entries.
  ///
  /// In en, this message translates to:
  /// **'Quests'**
  String get logsSegmentQuests;

  /// Log row subtitle for a district the player has entered.
  ///
  /// In en, this message translates to:
  /// **'First entered {day} · {percent}% charted'**
  String logsEntryDistrictCharted(String day, int percent);

  /// Log row subtitle for a place visited today.
  ///
  /// In en, this message translates to:
  /// **'Checked in today, {time}'**
  String logsEntryCheckedInToday(String time);

  /// Log row subtitle for an unidentified site close enough to reveal.
  ///
  /// In en, this message translates to:
  /// **'{distance} away · within quest radius'**
  String logsEntryWithinQuestRadius(String distance);

  /// Log row subtitle for an entry that requires travelling first.
  ///
  /// In en, this message translates to:
  /// **'Locked · travel there to reveal'**
  String get logsEntryLocked;

  /// Title of a place the player has detected but not identified.
  ///
  /// In en, this message translates to:
  /// **'Unknown site'**
  String get logsUnknownSite;

  /// Empty state on the logs screen.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet. Step outside and the map will fill in.'**
  String get logsEmpty;

  /// Title of the quests screen.
  ///
  /// In en, this message translates to:
  /// **'Quests'**
  String get questsTitle;

  /// How many quests are currently in progress.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active} other{{count} active}}'**
  String questsActiveCount(int count);

  /// Title of the highlighted weekly goal.
  ///
  /// In en, this message translates to:
  /// **'Weekly challenge'**
  String get questsWeeklyChallenge;

  /// Progress line of the weekly challenge.
  ///
  /// In en, this message translates to:
  /// **'Reveal {target} unknown sites · {done}/{target} done'**
  String questsWeeklyChallengeGoal(int target, int done);

  /// Quest asking the player to walk to an unidentified place.
  ///
  /// In en, this message translates to:
  /// **'Reveal the unknown site'**
  String get questsRevealSiteTitle;

  /// Distance and district of the quest target.
  ///
  /// In en, this message translates to:
  /// **'{distance} away · {district}'**
  String questsRevealSiteSubtitle(String distance, String district);

  /// Daily walking distance quest.
  ///
  /// In en, this message translates to:
  /// **'Walk {target} km today'**
  String questsWalkTitle(String target);

  /// Progress of the walking quest.
  ///
  /// In en, this message translates to:
  /// **'{done} / {target} km'**
  String questsWalkSubtitle(String done, String target);

  /// Quest asking the player to cross into an uncharted district.
  ///
  /// In en, this message translates to:
  /// **'Enter a new district'**
  String get questsNewDistrictTitle;

  /// Closest uncharted district and how far away it is.
  ///
  /// In en, this message translates to:
  /// **'Nearest: {district} · {distance}'**
  String questsNewDistrictSubtitle(String district, String distance);

  /// Locked quest about exploring after dark.
  ///
  /// In en, this message translates to:
  /// **'Night wanderer'**
  String get questsNightWandererTitle;

  /// Requirement line on a locked quest.
  ///
  /// In en, this message translates to:
  /// **'Unlocks at level {level}'**
  String questsUnlocksAtLevel(int level);

  /// Title of the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Player rank and total experience.
  ///
  /// In en, this message translates to:
  /// **'Level {level} Explorer · {xp} XP'**
  String profileLevelLine(int level, int xp);

  /// Percentage of the city the player has uncovered.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String profileChartedShare(int percent);

  /// Caption under the big charted percentage.
  ///
  /// In en, this message translates to:
  /// **'of the city charted'**
  String get profileChartedCaption;

  /// Stat tile: how far the player walked today.
  ///
  /// In en, this message translates to:
  /// **'Distance today'**
  String get profileStatDistanceToday;

  /// Stat tile: number of distinct places checked in to.
  ///
  /// In en, this message translates to:
  /// **'Check-in places'**
  String get profileStatCheckIns;

  /// Stat tile: consecutive days with activity.
  ///
  /// In en, this message translates to:
  /// **'Active streak'**
  String get profileStatStreak;

  /// Chip marking the city the player is exploring right now.
  ///
  /// In en, this message translates to:
  /// **'{city} · current'**
  String profileCityCurrent(String city);

  /// Chip that starts tracking another city.
  ///
  /// In en, this message translates to:
  /// **'+ Add city'**
  String get profileAddCity;

  /// Header of the per-district progress card.
  ///
  /// In en, this message translates to:
  /// **'City progress · {city}'**
  String profileCityProgressTitle(String city);

  /// Header of the leaderboard card.
  ///
  /// In en, this message translates to:
  /// **'City ranking'**
  String get profileRankingTitle;

  /// Where the player sits on the city leaderboard.
  ///
  /// In en, this message translates to:
  /// **'You\'\'re #{rank} of {total} explorers'**
  String profileRankingSubtitle(int rank, int total);

  /// How much the player climbed the leaderboard this week.
  ///
  /// In en, this message translates to:
  /// **'+{percent}%'**
  String profileRankingTrend(int percent);

  /// Supporting line under the place name in the check-in sheet.
  ///
  /// In en, this message translates to:
  /// **'{category} · {distance} away · {visited, select, never{never visited} other{visited before}}'**
  String checkInSheetMeta(String category, String distance, String visited);

  /// Caption of the tile counting other players at this place.
  ///
  /// In en, this message translates to:
  /// **'explorers here'**
  String get checkInExplorersHere;

  /// Value of the tile announcing a first-visit bonus.
  ///
  /// In en, this message translates to:
  /// **'First'**
  String get checkInFirstVisit;

  /// Caption explaining the doubled reward for a first visit.
  ///
  /// In en, this message translates to:
  /// **'visit bonus ×2'**
  String get checkInFirstVisitBonus;

  /// Caption of the tile showing the streak this check-in preserves.
  ///
  /// In en, this message translates to:
  /// **'streak kept'**
  String get checkInStreakKept;

  /// Primary button of the check-in sheet.
  ///
  /// In en, this message translates to:
  /// **'Check in here'**
  String get checkInAction;

  /// Header above the list of alternative nearby places.
  ///
  /// In en, this message translates to:
  /// **'Not this place? Pick the right one'**
  String get checkInWrongPlaceTitle;

  /// Confirmation shown after a successful check-in.
  ///
  /// In en, this message translates to:
  /// **'Checked in at {place}'**
  String checkInSuccess(String place);

  /// Shown when a check-in is refused because the player moved out of range.
  ///
  /// In en, this message translates to:
  /// **'You\'\'re too far away to check in here.'**
  String get checkInTooFar;

  /// Generic failure message for a check-in that could not be recorded.
  ///
  /// In en, this message translates to:
  /// **'That didn\'\'t work. Try again in a moment.'**
  String get checkInFailed;

  /// Overline on the celebration screen. Displayed in upper case.
  ///
  /// In en, this message translates to:
  /// **'NEW DISTRICT DISCOVERED'**
  String get discoveryKicker;

  /// Which district this is out of the city total.
  ///
  /// In en, this message translates to:
  /// **'District {index} of {total} · {city}'**
  String discoveryMeta(int index, int total, String city);

  /// Button that closes the celebration and returns to the map.
  ///
  /// In en, this message translates to:
  /// **'Start exploring'**
  String get discoveryAction;

  /// Settings section grouping the three kinds of map point.
  ///
  /// In en, this message translates to:
  /// **'Points on the map'**
  String get settingsMapLayers;

  /// Toggle for points that come from the places data.
  ///
  /// In en, this message translates to:
  /// **'Suggested places'**
  String get settingsShowSuggestedPoints;

  /// Supporting line explaining where suggested points come from.
  ///
  /// In en, this message translates to:
  /// **'Places we found near you'**
  String get settingsShowSuggestedPointsDetail;

  /// Toggle for points the player dropped themselves.
  ///
  /// In en, this message translates to:
  /// **'My points'**
  String get settingsHideUserPoints;

  /// Supporting line for the player's own dropped pins.
  ///
  /// In en, this message translates to:
  /// **'Pins you dropped yourself'**
  String get settingsHideUserPointsDetail;

  /// Toggle for points created from a photo.
  ///
  /// In en, this message translates to:
  /// **'Photo points'**
  String get settingsHidePicturePoints;

  /// Supporting line for photo points.
  ///
  /// In en, this message translates to:
  /// **'Places you photographed'**
  String get settingsHidePicturePointsDetail;

  /// Title of the screen for tuning how the fog of war behaves.
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get settingsFogTitle;

  /// Supporting line on the settings row that opens the fog screen.
  ///
  /// In en, this message translates to:
  /// **'How much walking uncovers'**
  String get settingsFogSubtitle;

  /// Setting for how much ground one position uncovers.
  ///
  /// In en, this message translates to:
  /// **'Clearing size'**
  String get settingsFogClearingRadius;

  /// Explains the clearing size setting in plain terms.
  ///
  /// In en, this message translates to:
  /// **'How far you can see from where you stand'**
  String get settingsFogClearingRadiusDetail;

  /// Setting for how finely the walked trail is recorded.
  ///
  /// In en, this message translates to:
  /// **'Recording precision'**
  String get settingsFogPrecision;

  /// Explains the trade-off behind the recording precision setting.
  ///
  /// In en, this message translates to:
  /// **'Finer keeps a truer trail and a bigger file'**
  String get settingsFogPrecisionDetail;

  /// Title of the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings row that changes the app language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Language option following the device setting.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// Debug-only settings row opening the component catalogue.
  ///
  /// In en, this message translates to:
  /// **'Design system gallery'**
  String get settingsDesignGallery;

  /// Banner on the map when the device's location service is disabled.
  ///
  /// In en, this message translates to:
  /// **'Location is switched off'**
  String get locationServiceOffTitle;

  /// Explains the consequence of the location service being off.
  ///
  /// In en, this message translates to:
  /// **'NoPlace cannot uncover the map without it.'**
  String get locationServiceOffBody;

  /// Banner on the map when the location permission was refused but can be asked for again.
  ///
  /// In en, this message translates to:
  /// **'NoPlace needs your location'**
  String get locationDeniedTitle;

  /// Explains why the app needs location, in terms of the product rather than the permission.
  ///
  /// In en, this message translates to:
  /// **'Walking is what uncovers the map, so we need to know where you are.'**
  String get locationDeniedBody;

  /// Banner when the permission is permanently denied and only Settings can undo it.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked'**
  String get locationDeniedForeverTitle;

  /// Tells the player the only remaining route is the OS settings screen.
  ///
  /// In en, this message translates to:
  /// **'Turn it back on in Settings to keep uncovering the map.'**
  String get locationDeniedForeverBody;

  /// Button opening the device location settings.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get locationActionTurnOn;

  /// Button asking for the location permission again.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get locationActionAllow;

  /// Button opening the app's settings page in the OS.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get locationActionSettings;

  /// Shown while permission is granted but no GPS fix has arrived yet.
  ///
  /// In en, this message translates to:
  /// **'Looking for you…'**
  String get locationWaiting;

  /// Headline of the nearby card when the closest place is too far to claim.
  ///
  /// In en, this message translates to:
  /// **'Nearest · {place}'**
  String mapNearestTitle(String place);

  /// Supporting line when the nearest place is out of check-in range.
  ///
  /// In en, this message translates to:
  /// **'{distance} away · walk closer to check in'**
  String mapNearestMeta(Object distance);

  /// Headline of the nearby card when no place is known at all.
  ///
  /// In en, this message translates to:
  /// **'Nothing mapped here yet'**
  String get mapNothingNearbyTitle;

  /// Reassures the player that walking is still worthwhile with no place in range.
  ///
  /// In en, this message translates to:
  /// **'Keep walking — the map still opens as you go.'**
  String get mapNothingNearbyBody;

  /// Accessibility label for the button that puts the map back on the player.
  ///
  /// In en, this message translates to:
  /// **'Centre on me'**
  String get mapRecentre;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'vi':
      return AppL10nVi();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
