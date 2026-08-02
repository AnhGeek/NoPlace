import 'package:equatable/equatable.dart';

/// One line in the explorer's log.
///
/// Sealed so the UI has to handle every kind: adding a new entry type breaks
/// the `switch` in the log list at compile time instead of silently rendering
/// nothing. The entries carry *data*, never localised strings — the widget
/// turns them into words.
sealed class LogEntry extends Equatable {
  const LogEntry({required this.id, required this.at, this.xpAwarded});

  final String id;

  /// When it happened. Locked entries use the moment they became visible so the
  /// list keeps a stable order.
  final DateTime at;

  final int? xpAwarded;

  @override
  List<Object?> get props => [id, at, xpAwarded];
}

/// The player entered a district for the first time.
final class DistrictLogEntry extends LogEntry {
  const DistrictLogEntry({
    required super.id,
    required super.at,
    required this.districtName,
    required this.chartedFraction,
    super.xpAwarded,
  });

  final String districtName;
  final double chartedFraction;

  @override
  List<Object?> get props => [...super.props, districtName, chartedFraction];
}

/// The player checked in at a place.
final class CheckInLogEntry extends LogEntry {
  const CheckInLogEntry({
    required super.id,
    required super.at,
    required this.placeName,
    super.xpAwarded,
  });

  final String placeName;

  @override
  List<Object?> get props => [...super.props, placeName];
}

/// A site the player detected but has not identified yet — the hook that pulls
/// them a few streets further.
final class UnknownSiteLogEntry extends LogEntry {
  const UnknownSiteLogEntry({
    required super.id,
    required super.at,
    required this.distanceMeters,
    super.xpAwarded,
  });

  final double distanceMeters;

  @override
  List<Object?> get props => [...super.props, distanceMeters];
}

/// A placeholder for something that exists but is not revealed yet.
final class LockedLogEntry extends LogEntry {
  const LockedLogEntry({required super.id, required super.at});
}
