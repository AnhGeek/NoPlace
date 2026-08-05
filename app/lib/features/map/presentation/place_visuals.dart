import 'package:flutter/material.dart';

import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../domain/entities/auto_check_in.dart';
import '../../../domain/entities/map_point.dart';
import '../../../domain/entities/place.dart';
import '../../../l10n/l10n.dart';

/// How a place category looks and what we call it.
///
/// The mapping lives in the feature, not in the design system: the design
/// system knows about colours and icons, the feature knows what a "market" is.
extension PlaceVisuals on PlaceCategory {
  IconData get icon => switch (this) {
    PlaceCategory.food => Icons.restaurant_rounded,
    PlaceCategory.cafe => Icons.local_cafe_rounded,
    PlaceCategory.landmark => Icons.account_balance_rounded,
    PlaceCategory.park => Icons.park_rounded,
    PlaceCategory.market => Icons.storefront_rounded,
    PlaceCategory.unknown => Icons.question_mark_rounded,
  };

  Color get color => switch (this) {
    PlaceCategory.food => NpColors.categoryFood,
    PlaceCategory.cafe => NpColors.categoryCafe,
    PlaceCategory.landmark => NpColors.categoryLandmark,
    PlaceCategory.park => NpColors.categoryPark,
    PlaceCategory.market => NpColors.categoryMarket,
    PlaceCategory.unknown => NpColors.categoryUnknown,
  };
}

/// The name to show for a place — unidentified sites keep their mystery.
String placeDisplayName(Place place, AppL10n l10n) =>
    place.isIdentified ? place.name : l10n.logsUnknownSite;

/// Icons a player can pick for their own points.
///
/// The stored value is a string id, not an `IconData`: Flutter's code points
/// are not a storage format. An id we no longer recognise falls back to the
/// plain pin rather than rendering a blank square.
IconData userPointIcon(String iconId) => switch (iconId) {
  'star' => Icons.star_rounded,
  'heart' => Icons.favorite_rounded,
  'home' => Icons.home_rounded,
  'coffee' => Icons.local_cafe_rounded,
  'food' => Icons.restaurant_rounded,
  'boba' => Icons.emoji_food_beverage_rounded,
  'ramen' => Icons.ramen_dining_rounded,
  'cake' => Icons.cake_rounded,
  'icecream' => Icons.icecream_rounded,
  'pet' => Icons.pets_rounded,
  'flower' => Icons.local_florist_rounded,
  'shop' => Icons.shopping_bag_rounded,
  'music' => Icons.music_note_rounded,
  'sparkle' => Icons.auto_awesome_rounded,
  'beach' => Icons.beach_access_rounded,
  'moon' => Icons.nightlight_round,
  'work' => Icons.work_rounded,
  'view' => Icons.photo_camera_outlined,
  'flag' => Icons.flag_rounded,
  _ => Icons.push_pin_rounded,
};

/// The face on a recorded feeling.
///
/// An emoji rather than an icon, and the one place in the app that is: this is
/// the player's own reaction to a place, and a monochrome glyph flattens
/// "loved it" and "never again" into the same grey pictogram. Unknown ids get
/// nothing at all — a mood we cannot draw is better absent than guessed.
String placeMoodEmoji(String moodId) => switch (moodId) {
  PlaceMood.love => '😍',
  PlaceMood.happy => '😊',
  PlaceMood.calm => '😌',
  PlaceMood.meh => '😐',
  PlaceMood.bad => '😖',
  _ => '',
};

/// What that feeling is called, in the player's language.
String placeMoodLabel(String moodId, AppL10n l10n) => switch (moodId) {
  PlaceMood.love => l10n.placeMoodLove,
  PlaceMood.happy => l10n.placeMoodHappy,
  PlaceMood.calm => l10n.placeMoodCalm,
  PlaceMood.meh => l10n.placeMoodMeh,
  PlaceMood.bad => l10n.placeMoodBad,
  _ => '',
};

/// What to call a point the player made. An unnamed pin is legitimate — you
/// drop one to remember a spot, not to fill in a form — so it gets a name here
/// rather than an empty line on every screen that lists it.
String mapPointDisplayName(MapPoint point, AppL10n l10n) =>
    point.label.isNotEmpty ? point.label : l10n.placeUnnamed;

/// The name of an auto check-in interval, short enough for a picker segment.
///
/// Written out per option rather than composed from a number and a unit,
/// because "30 min" and "1 hour" are not the same sentence in every language —
/// and an interval we no longer offer falls back to the default's label rather
/// than printing a raw duration.
String autoCheckInLabel(Duration every, AppL10n l10n) => switch (every) {
  AutoCheckIn.off => l10n.placeAutoCheckInOff,
  AutoCheckIn.halfHourly => l10n.placeAutoCheckInHalfHourly,
  AutoCheckIn.twoHourly => l10n.placeAutoCheckInTwoHourly,
  _ => l10n.placeAutoCheckInHourly,
};

/// What that interval will actually do, as a full sentence for under the visit
/// count. See [autoCheckInLabel] for why each one is written out.
String autoCheckInSummary(Duration every, AppL10n l10n) => switch (every) {
  AutoCheckIn.off => l10n.placeAutoCheckInSummaryOff,
  AutoCheckIn.halfHourly => l10n.placeAutoCheckInSummaryHalfHourly,
  AutoCheckIn.twoHourly => l10n.placeAutoCheckInSummaryTwoHourly,
  _ => l10n.placeAutoCheckInSummaryHourly,
};
