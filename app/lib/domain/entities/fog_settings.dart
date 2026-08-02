import 'package:equatable/equatable.dart';

import '../rules/exploration_rules.dart';

/// The two numbers that decide how the fog behaves.
///
/// They are settings rather than constants because the right values cannot be
/// argued out on paper — they have to be walked. Both are clamped to ranges
/// that keep the map usable: outside these, the fog either never opens or opens
/// so fast there is no game.
class FogSettings extends Equatable {
  const FogSettings({
    this.clearingRadiusMeters = ExplorationRules.fogClearingRadiusMeters,
    this.recordingPrecisionMeters =
        ExplorationRules.defaultRecordingPrecisionMeters,
  });

  /// How much ground one position fix uncovers.
  final double clearingRadiusMeters;

  /// How finely positions are recorded. One metre keeps the truest record of
  /// where you walked; coarser values trade detail for a smaller database.
  final double recordingPrecisionMeters;

  static const double minClearingRadius = 40;
  static const double maxClearingRadius = 400;

  /// The precisions worth offering. A continuous slider would suggest the
  /// difference between 3 m and 4 m matters; it does not.
  static const List<double> precisionSteps = [1, 2, 5, 10, 25];

  /// Roughly how much of the visible clearing comes from the player's own
  /// position rather than the trail.
  double get playerVisibilityRadiusMeters => clearingRadiusMeters * 1.2;

  FogSettings copyWith({
    double? clearingRadiusMeters,
    double? recordingPrecisionMeters,
  }) => FogSettings(
    clearingRadiusMeters: (clearingRadiusMeters ?? this.clearingRadiusMeters)
        .clamp(minClearingRadius, maxClearingRadius),
    recordingPrecisionMeters:
        recordingPrecisionMeters ?? this.recordingPrecisionMeters,
  );

  @override
  List<Object?> get props => [clearingRadiusMeters, recordingPrecisionMeters];
}
