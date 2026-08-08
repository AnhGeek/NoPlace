import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';

/// Formats physical quantities for display.
///
/// Rules, applied everywhere so the product reads consistently:
/// * under 1 km → whole metres, rounded to 10 m ("480 m");
/// * 1 km and above → one decimal ("4.2 km");
/// * the number itself is formatted for the active locale (Vietnamese uses a
///   comma as the decimal separator).
class UnitFormatter {
  const UnitFormatter(this._l10n, this._localeName);

  factory UnitFormatter.of(AppL10n l10n) =>
      UnitFormatter(l10n, l10n.localeName);

  final AppL10n _l10n;
  final String _localeName;

  static const double _metersPerKilometer = 1000;

  String distance(double meters) {
    if (meters < _metersPerKilometer) {
      final rounded = meters < 100
          ? meters.round()
          : (meters / 10).round() * 10;
      return _l10n.commonDistanceMeters(rounded);
    }
    return _l10n.commonDistanceKilometers(kilometers(meters));
  }

  /// The bare number of kilometres, one decimal, no unit — for progress lines
  /// that print "4.2 / 5.0 km".
  String kilometers(double meters) =>
      NumberFormat('0.0', _localeName).format(meters / _metersPerKilometer);

  /// Same, but without a pointless ".0" — for goals ("Walk 5 km today") where
  /// the round number *is* the point.
  String kilometersCompact(double meters) =>
      NumberFormat('0.#', _localeName).format(meters / _metersPerKilometer);

  /// An area in square kilometres.
  ///
  /// Two decimals under one km², one above: the first walk of a new city is
  /// worth a fraction of a square kilometre and "0.0 km²" would read as nothing
  /// at all, while "12.42 km²" is a precision the estimate does not have.
  String squareKilometers(double squareMeters) {
    final value = squareMeters / 1000000;
    final pattern = value < 1 ? '0.00' : '0.0';
    return _l10n.commonAreaSquareKilometers(
      NumberFormat(pattern, _localeName).format(value),
    );
  }

  String percent(double fraction) =>
      NumberFormat.decimalPattern(_localeName).format((fraction * 100).round());

  String integer(int value) =>
      NumberFormat.decimalPattern(_localeName).format(value);

  /// Short weekday name ("Tue" / "Th 3") used by the log rows.
  String weekday(DateTime date) => DateFormat.E(_localeName).format(date);

  /// Wall-clock time without a date ("9:12").
  String timeOfDay(DateTime date) => DateFormat.jm(_localeName).format(date);
}
