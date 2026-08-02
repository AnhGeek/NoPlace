import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/gallery/design_gallery_screen.dart';
import '../../domain/entities/district.dart';
import '../../features/discovery/presentation/district_discovered_screen.dart';
import '../../features/logs/presentation/logs_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/quests/presentation/quests_screen.dart';
import '../../features/settings/presentation/fog_settings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../shell/home_shell.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The router.
///
/// A [StatefulShellRoute] gives each tab its own navigation stack, so switching
/// tabs and coming back lands the player exactly where they were — including
/// the map's camera position.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoute.mapPath,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.mapPath,
                name: AppRoute.mapName,
                builder: (context, state) => const MapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.logsPath,
                name: AppRoute.logsName,
                builder: (context, state) => const LogsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.questsPath,
                name: AppRoute.questsName,
                builder: (context, state) => const QuestsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.profilePath,
                name: AppRoute.profileName,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    name: AppRoute.settingsName,
                    builder: (context, state) => const SettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'fog',
                        name: AppRoute.fogSettingsName,
                        builder: (context, state) => const FogSettingsScreen(),
                      ),
                      GoRoute(
                        path: 'design-gallery',
                        name: AppRoute.galleryName,
                        builder: (context, state) =>
                            const DesignGalleryScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.discoveryPath,
        name: AppRoute.discoveryName,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final district = state.extra! as District;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            fullscreenDialog: true,
            opaque: false,
            transitionsBuilder: (context, animation, secondary, child) =>
                FadeTransition(opacity: animation, child: child),
            child: DistrictDiscoveredScreen(district: district),
          );
        },
      ),
    ],
  );
});
