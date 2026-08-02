import 'package:flutter/material.dart';

import '../../../design_system/tokens/design_tokens.g.dart';
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
  'view' => Icons.photo_camera_outlined,
  'flag' => Icons.flag_rounded,
  _ => Icons.push_pin_rounded,
};
