/// Every navigable destination in the app, in one place.
///
/// Screens never write a path literal: they use `AppRoute.logs.go(context)` or
/// the name constants below, so renaming a URL is a single-file change and deep
/// links stay verifiable.
abstract final class AppRoute {
  const AppRoute._();

  // Shell branches — one per bottom-navigation destination.
  static const String mapPath = '/map';
  static const String mapName = 'map';

  static const String logsPath = '/logs';
  static const String logsName = 'logs';

  static const String questsPath = '/quests';
  static const String questsName = 'quests';

  static const String profilePath = '/profile';
  static const String profileName = 'profile';

  // Pushed over the shell.
  static const String settingsPath = '/settings';
  static const String settingsName = 'settings';

  static const String galleryPath = '/settings/design-gallery';
  static const String galleryName = 'design-gallery';

  static const String fogSettingsPath = '/settings/fog';
  static const String fogSettingsName = 'fog-settings';

  static const String backupPath = '/settings/backup';
  static const String backupName = 'backup';

  /// Full-screen celebration. Takes the discovered district as `extra`.
  static const String discoveryPath = '/discovery';
  static const String discoveryName = 'discovery';
}
