/// The in-memory representation of a single design token, after aliases have
/// been resolved.
class Token {
  Token({
    required this.path,
    required this.type,
    required this.value,
    this.description,
  });

  /// Dotted path of the token, e.g. `['color', 'background', 'canvas']`.
  final List<String> path;

  /// DTCG `$type`, inherited from the nearest ancestor group when absent.
  final String type;

  /// Resolved value. String, num, List (cubicBezier) or Map (shadow).
  final Object value;

  final String? description;

  String get name => path.join('.');

  /// Path with [prefixLength] leading segments removed, camelCased.
  String memberName(int prefixLength) {
    final parts = path.sublist(prefixLength);
    final buffer = StringBuffer(parts.first);
    for (final part in parts.skip(1)) {
      buffer.write(part[0].toUpperCase() + part.substring(1));
    }
    return buffer.toString();
  }

  String get snakeName => path.join('_').replaceAllMapped(
    RegExp('([a-z0-9])([A-Z])'),
    (m) => '${m[1]}_${m[2]!.toLowerCase()}',
  );

  @override
  String toString() => '$name = $value ($type)';
}

/// A colour parsed from a `#RRGGBB` or `#RRGGBBAA` string.
class TokenColor {
  const TokenColor(this.r, this.g, this.b, this.a);

  factory TokenColor.parse(String hex) {
    final raw = hex.replaceFirst('#', '');
    if (raw.length != 6 && raw.length != 8) {
      throw FormatException('Unsupported colour literal: $hex');
    }
    return TokenColor(
      int.parse(raw.substring(0, 2), radix: 16),
      int.parse(raw.substring(2, 4), radix: 16),
      int.parse(raw.substring(4, 6), radix: 16),
      raw.length == 8 ? int.parse(raw.substring(6, 8), radix: 16) : 255,
    );
  }

  final int r;
  final int g;
  final int b;
  final int a;

  bool get isOpaque => a == 255;

  String get argbHex =>
      '${_hex(a)}${_hex(r)}${_hex(g)}${_hex(b)}'.toUpperCase();

  String get rgbaCss => isOpaque
      ? '#${_hex(r)}${_hex(g)}${_hex(b)}'
      : 'rgba($r, $g, $b, ${(a / 255).toStringAsFixed(2)})';

  String _hex(int v) => v.toRadixString(16).padLeft(2, '0');
}

/// Millisecond value of a `duration` token such as `240ms`.
int parseDurationMs(Object value) {
  final text = value.toString().trim();
  if (text.endsWith('ms')) return int.parse(text.substring(0, text.length - 2));
  if (text.endsWith('s')) {
    return (double.parse(text.substring(0, text.length - 1)) * 1000).round();
  }
  return int.parse(text);
}

/// Numeric value of a `dimension`/`number` token. Unit-less by convention: the
/// unit is decided by the emitter (dp, pt, px).
double parseNumber(Object value) {
  if (value is num) return value.toDouble();
  return double.parse(value.toString().replaceAll(RegExp('[a-zA-Z%]'), ''));
}

/// Formats a double the way Dart source likes it: `16` stays `16`, `1.5` stays
/// `1.5`.
String formatNumber(double value) {
  if (value == value.roundToDouble() && value.abs() < 1e9) {
    return value.toInt().toString();
  }
  return value.toString();
}
