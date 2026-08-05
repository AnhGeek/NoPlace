import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/noplace_app.dart';
import 'data/local/app_database.dart';
import 'data/local/demo_map_points.dart';
import 'data/local/region_catalogue.dart';
import 'data/local/sqlite_map_point_repository.dart';
import 'data/local/sqlite_preferences_repository.dart';
import 'data/local/sqlite_trail_repository.dart';
import 'data/repository_providers.dart';
import 'design_system/theme/np_theme.dart';

/// Held for the process lifetime: an [AppLifecycleListener] stops firing if it
/// is collected, and this one is what gets the fog to disk on a swipe-away.
AppLifecycleListener? _lifecycleListener;

/// Starts the app with everything that must happen before the first frame.
///
/// Every entry point (`main.dart`, and the flavour entry points that will join
/// it) funnels through here, so start-up work is written once and cannot drift
/// between builds.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only: the map, the sheets and the fog mask are all designed for a
  // tall viewport, and a landscape city map is a different product.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(NpTheme.overlayStyle);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // Crash reporting hooks in here once it is chosen; until then a debug
    // build must still make the failure loud.
    if (kReleaseMode) {
      debugPrint('Unhandled Flutter error: ${details.exceptionAsString()}');
    }
  };

  // Open the database and read everything the map needs before the first
  // frame. Three small queries, and doing them here is the difference between
  // the city appearing as the player left it and the fog visibly snapping open
  // a moment after launch.
  final database = AppDatabase();
  // The starting region: the fallback, because the GPS has not answered yet.
  // The map resolves the real one from the first fix and calls `switchTo` —
  // see `regionPackSourceProvider`. It is also where a trail written before the
  // schema was region-scoped ends up.
  final fogTrail = SqliteTrailRepository(
    database,
    regionId: RegionCatalogue.fallback.regionId,
  );
  final mapPoints = SqliteMapPointRepository(database);
  final preferences = SqlitePreferencesRepository(database);

  await fogTrail.load();
  await mapPoints.load();
  await preferences.load();

  // Carries across a trail written by the build before the database existed,
  // then removes the old file.
  await fogTrail.importLegacyJson(
    File('${(await getApplicationSupportDirectory()).path}/fog_trail.json'),
  );

  // Something to look at until the pin-dropping and photo flows are built.
  await mapPoints.seedIfEmpty(DemoMapPoints.seed());

  // Anything buffered in memory hits the disk when the app leaves the
  // foreground — a swipe-away must never cost somebody a walk.
  _lifecycleListener = AppLifecycleListener(
    onHide: () => unawaited(fogTrail.flush()),
    onPause: () => unawaited(fogTrail.flush()),
    onDetach: () {
      unawaited(fogTrail.flush());
      _lifecycleListener?.dispose();
      _lifecycleListener = null;
    },
  );

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        trailStoreProvider.overrideWithValue(fogTrail),
        mapPointStoreProvider.overrideWithValue(mapPoints),
        preferencesStoreProvider.overrideWithValue(preferences),
      ],
      child: const NoPlaceApp(),
    ),
  );
}
