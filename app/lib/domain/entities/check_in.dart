import 'package:equatable/equatable.dart';

import 'district.dart';
import 'place.dart';

/// What the player gets back after checking in.
///
/// Everything the celebration UI needs is in here, so the check-in flow never
/// has to re-query state that has just changed underneath it.
class CheckInResult extends Equatable {
  const CheckInResult({
    required this.place,
    required this.xpAwarded,
    required this.isFirstVisit,
    required this.streakDays,
    this.districtDiscovered,
  });

  final Place place;
  final int xpAwarded;

  /// First visits are worth double — the reason the sheet shows a "×2" tile.
  final bool isFirstVisit;

  final int streakDays;

  /// Set when this check-in was also the player's first step into a district,
  /// which triggers the full-screen discovery moment.
  final District? districtDiscovered;

  @override
  List<Object?> get props => [
    place,
    xpAwarded,
    isFirstVisit,
    streakDays,
    districtDiscovered,
  ];
}
