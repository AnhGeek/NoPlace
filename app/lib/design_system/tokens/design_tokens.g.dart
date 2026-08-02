// GENERATED FILE — DO NOT EDIT.
//
// Source:    design/tokens/*.json
// Generator: dart run tools/token_builder/bin/build_tokens.dart
//
// Edit the JSON, re-run the generator, commit both.

// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter/widgets.dart';

/// Generated from `border`.
abstract final class NpBorderWidth {
  static const double hairline = 1;
  static const double heavy = 3;
  static const double thick = 2;
  static const double thin = 1.5;
}

/// Generated from `color`.
abstract final class NpColors {
  static const Color accentDefault = Color(0xFFF56B26);

  /// 70% ember — the halo around the player dot.
  static const Color accentGlow = Color(0xB3F56B26);
  static const Color accentHover = Color(0xFFFF8B4D);

  /// 16% ember — selected chips, active tab background.
  static const Color accentSubtle = Color(0x29F56B26);

  /// Behind everything, including the map when tiles have not loaded.
  static const Color backgroundCanvas = Color(0xFF08080A);

  /// Ground the player has uncovered. Without a basemap this colour *is* the reward, so it has to read clearly against the fog.
  static const Color backgroundExploredGround = Color(0xFF1C1C24);

  /// Unexplored ground. Opaque: with no basemap beneath, a translucent fog would only reveal more of the same black.
  static const Color backgroundFog = Color(0xFF040406);

  /// Cards, list rows, segmented controls.
  static const Color backgroundPanel = Color(0xFF161618);

  /// Sheets and anything floating above the map.
  static const Color backgroundPanelRaised = Color(0xFF1B1B1F);
  static const Color backgroundPanelSunken = Color(0xFF2C2C31);
  static const Color backgroundScrim = Color(0x8C000000);

  /// Default screen background.
  static const Color backgroundSurface = Color(0xFF0D0D0F);
  static const Color borderOnMedia = Color(0xFFFFFFFF);
  static const Color borderStrong = Color(0xFF3A3A40);
  static const Color borderSubtle = Color(0xFF26262A);
  static const Color categoryCafe = Color(0xFF2FB9C4);
  static const Color categoryFood = Color(0xFFF56B26);
  static const Color categoryLandmark = Color(0xFFD99A2B);
  static const Color categoryMarket = Color(0xFFF56B26);
  static const Color categoryPark = Color(0xFF27B263);

  /// A site the player has not identified yet.
  static const Color categoryUnknown = Color(0xFF8A8A92);
  static const Color chartSeries1 = Color(0xFFF56B26);
  static const Color chartSeries2 = Color(0xFF316DCA);
  static const Color chartSeries3 = Color(0xFF347D39);
  static const Color chartTrack = Color(0xFF26262A);
  static const Color contentMuted = Color(0xFF8A8A92);
  static const Color contentOnAccent = Color(0xFFFFFFFF);
  static const Color contentOnStatus = Color(0xFFFFFFFF);
  static const Color contentPlaceholder = Color(0xFF5C5C64);
  static const Color contentPrimary = Color(0xFFF2F2F4);
  static const Color contentSecondary = Color(0xFFCFCFD6);

  /// District edges, drawn with the rest of the map and therefore hidden by the fog.
  static const Color mapBoundary = Color(0xFF3A3A40);

  /// Building footprints. Visible at walking zoom, invisible at city zoom.
  static const Color mapBuilding = Color(0xFF24242E);

  /// 35% ember — the edge of the city, drawn *above* the fog. It is the one line that shows what has not been explored yet, so it has to read against unexplored black without competing with a pin.
  static const Color mapCityBorder = Color(0x59F56B26);

  /// Land. The same colour as uncovered ground, so the basemap appears to *be* the ground rather than sit on it.
  static const Color mapEarth = Color(0xFF1C1C24);

  /// Street and place names. Muted on purpose: legible when looked for, never competing with a pin.
  static const Color mapLabel = Color(0xFF8A8A92);

  /// 80% canvas, painted behind label text so it stays readable over roads and water alike.
  static const Color mapLabelHalo = Color(0xCC08080A);

  /// Names of localities and neighbourhoods.
  static const Color mapLabelStrong = Color(0xFFCFCFD6);

  /// Built-up and institutional areas — a barely-there lift off earth.
  static const Color mapLanduse = Color(0xFF1F1F28);

  /// Parks and greenery. A hint of moss, well below the saturation of category.park.
  static const Color mapPark = Color(0xFF182620);

  /// Footpaths and alleys.
  static const Color mapPath = Color(0xFF2A2A33);
  static const Color mapRail = Color(0xFF33333D);

  /// Motorways and trunk roads, the brightest geometry on the map.
  static const Color mapRoadHighway = Color(0xFF4A4A58);

  /// Arterials. The lines that let you recognise a district from its shape.
  static const Color mapRoadMajor = Color(0xFF3D3D49);

  /// Residential streets and service roads — most of what a walker actually uses.
  static const Color mapRoadMinor = Color(0xFF2E2E38);

  /// Rivers and the sea. Blue enough to read as water at a glance, dark enough not to glow.
  static const Color mapWater = Color(0xFF12212E);
  static const Color statusInfo = Color(0xFF316DCA);
  static const Color statusLocked = Color(0xFF2C2C31);
  static const Color statusRare = Color(0xFF8256D0);
  static const Color statusSuccess = Color(0xFF27B263);
  static const Color statusSuccessMuted = Color(0xFF347D39);
  static const Color statusWarning = Color(0xFFCC6B2C);
}

/// Generated from `duration`.
abstract final class NpDuration {
  static const Duration base = Duration(milliseconds: 240);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration pulse = Duration(milliseconds: 2400);
  static const Duration reveal = Duration(milliseconds: 700);
  static const Duration slow = Duration(milliseconds: 360);
}

/// Generated from `easing`.
abstract final class NpEasing {
  static const Cubic accelerate = Cubic(0.3, 0, 1, 1);
  static const Cubic decelerate = Cubic(0, 0, 0, 1);
  static const Cubic emphasized = Cubic(0.2, 0, 0, 1.2);
  static const Cubic standard = Cubic(0.2, 0, 0, 1);
}

/// Generated from `font.family`.
abstract final class NpFontFamily {
  static const String sans = 'Barlow';
}

/// Generated from `font.size`.
abstract final class NpFontSize {
  static const double body = 14;
  static const double bodyLarge = 15;
  static const double caption = 12;
  static const double display = 22;
  static const double footnote = 13;
  static const double headline = 20;
  static const double hero = 26;
  static const double overline = 12;
  static const double stat = 34;
  static const double statHero = 42;
  static const double title = 17;
}

/// Generated from `font.weight`.
abstract final class NpFontWeight {
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight semibold = FontWeight.w600;
}

/// Generated from `font.lineHeight`.
abstract final class NpLineHeight {
  static const double normal = 1.4;
  static const double snug = 1.25;
  static const double tight = 1.15;
}

/// Generated from `opacity`.
abstract final class NpOpacity {
  static const double fog = 0.96;
  static const double locked = 0.45;
  static const double scrim = 0.55;
}

/// Generated from `palette`.
abstract final class NpPalette {
  static const Color cobalt500 = Color(0xFF316DCA);
  static const Color ember300 = Color(0xFFFF8B4D);
  static const Color ember500 = Color(0xFFF56B26);
  static const Color ember700 = Color(0xFFCC6B2C);
  static const Color ink0 = Color(0xFFFFFFFF);
  static const Color ink1000 = Color(0xFF000000);
  static const Color ink200 = Color(0xFFCFCFD6);
  static const Color ink400 = Color(0xFF8A8A92);
  static const Color ink450 = Color(0xFF66666E);
  static const Color ink50 = Color(0xFFF2F2F4);
  static const Color ink500 = Color(0xFF5C5C64);
  static const Color ink600 = Color(0xFF3A3A40);
  static const Color ink650 = Color(0xFF2C2C31);
  static const Color ink700 = Color(0xFF26262A);
  static const Color ink750 = Color(0xFF1B1B1F);
  static const Color ink800 = Color(0xFF161618);
  static const Color ink850 = Color(0xFF141417);
  static const Color ink900 = Color(0xFF0D0D0F);
  static const Color ink950 = Color(0xFF08080A);
  static const Color lagoon500 = Color(0xFF2FB9C4);
  static const Color moss500 = Color(0xFF27B263);
  static const Color moss700 = Color(0xFF347D39);
  static const Color orchid500 = Color(0xFF8256D0);
  static const Color sand500 = Color(0xFFD99A2B);
}

/// Generated from `radius`.
abstract final class NpRadius {
  static const double lg = 14;
  static const double md = 12;
  static const double pill = 999;
  static const double sheet = 22;
  static const double sm = 8;
  static const double xl = 16;
  static const double xs = 4;
  static const double xxl = 22;
}

/// Generated from `shadow`.
abstract final class NpShadows {
  static const BoxShadow card = BoxShadow(
    color: Color(0x80000000),
    offset: Offset(0, 6),
    blurRadius: 24,
    spreadRadius: 0,
  );
  static const BoxShadow marker = BoxShadow(
    color: Color(0x73000000),
    offset: Offset(0, 2),
    blurRadius: 8,
    spreadRadius: 0,
  );
  static const BoxShadow sheet = BoxShadow(
    color: Color(0xD9000000),
    offset: Offset(0, 12),
    blurRadius: 50,
    spreadRadius: 0,
  );
}

/// Generated from `size`.
abstract final class NpSize {
  static const double avatar = 78;
  static const double discoveryBadge = 86;
  static const double grabber = 44;
  static const double iconHero = 34;
  static const double iconLg = 20;
  static const double iconMd = 16;
  static const double iconSm = 14;
  static const double iconXl = 22;
  static const double iconXs = 12;
  static const double logMark = 38;
  static const double mapPin = 32;
  static const double mapPinSmall = 26;
  static const double navBarHeight = 64;
  static const double playerDot = 26;
  static const double playerHalo = 58;
  static const double progressBar = 6;
  static const double tabIndicator = 2;
  static const double touchTarget = 48;
}

/// Generated from `space`.
abstract final class NpSpace {
  static const double hair = 2;
  static const double huge = 40;
  static const double lg = 16;
  static const double md = 12;
  static const double none = 0;
  static const double sm = 10;
  static const double xl = 20;
  static const double xs = 8;
  static const double xxl = 24;
  static const double xxs = 4;
  static const double xxxl = 32;
}

/// Generated from `font.tracking`.
abstract final class NpTracking {
  static const double normal = 0;
  static const double tighter = -0.4;
  static const double wide = 1.8;
  static const double wider = 2.6;
  static const double widest = 3.4;
}
