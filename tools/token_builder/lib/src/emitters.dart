import 'dart:convert';

import 'token.dart';

const _banner = '''
// GENERATED FILE — DO NOT EDIT.
//
// Source:    design/tokens/*.json
// Generator: dart run tools/token_builder/bin/build_tokens.dart
//
// Edit the JSON, re-run the generator, commit both.
''';

/// Maps a token path prefix to the generated container name. Longest prefix
/// wins, so `font.size.*` lands in its own class while `space.*` does not need
/// nesting.
const Map<String, String> containers = {
  'palette': 'NpPalette',
  'color': 'NpColors',
  'shadow': 'NpShadows',
  'space': 'NpSpace',
  'radius': 'NpRadius',
  'border': 'NpBorderWidth',
  'size': 'NpSize',
  'opacity': 'NpOpacity',
  'font.family': 'NpFontFamily',
  'font.weight': 'NpFontWeight',
  'font.size': 'NpFontSize',
  'font.lineHeight': 'NpLineHeight',
  'font.tracking': 'NpTracking',
  'duration': 'NpDuration',
  'easing': 'NpEasing',
};

/// The prefix a token belongs to, plus how many path segments it eats.
({String container, int depth}) containerFor(Token token) {
  for (var depth = token.path.length - 1; depth > 0; depth--) {
    final prefix = token.path.take(depth).join('.');
    final container = containers[prefix];
    if (container != null) return (container: container, depth: depth);
  }
  throw StateError('No container configured for "${token.name}"');
}

// ---------------------------------------------------------------------------
// Dart / Flutter
// ---------------------------------------------------------------------------

String emitDart(List<Token> tokens) {
  final grouped = <String, List<Token>>{};
  final depths = <String, int>{};
  for (final token in tokens) {
    final target = containerFor(token);
    grouped.putIfAbsent(target.container, () => []).add(token);
    depths[target.container] = target.depth;
  }

  final buffer = StringBuffer()
    ..writeln(_banner)
    ..writeln('// ignore_for_file: lines_longer_than_80_chars')
    ..writeln()
    ..writeln("import 'package:flutter/widgets.dart';")
    ..writeln();

  final names = grouped.keys.toList()..sort();
  for (final name in names) {
    buffer
      ..writeln('/// Generated from `${_sourceGroupOf(name)}`.')
      ..writeln('abstract final class $name {');
    for (final token in grouped[name]!) {
      final description = token.description;
      if (description != null) {
        buffer.writeln('  /// $description');
      }
      buffer.writeln(
        '  static const ${_dartType(token)} '
        '${token.memberName(depths[name]!)} = ${_dartValue(token)};',
      );
    }
    buffer
      ..writeln('}')
      ..writeln();
  }
  return buffer.toString();
}

String _sourceGroupOf(String container) => containers.entries
    .firstWhere((e) => e.value == container)
    .key;

String _dartType(Token token) => switch (token.type) {
  'color' => 'Color',
  'dimension' || 'number' => 'double',
  'duration' => 'Duration',
  'fontFamily' => 'String',
  'fontWeight' => 'FontWeight',
  'cubicBezier' => 'Cubic',
  'shadow' => 'BoxShadow',
  _ => throw StateError('Unhandled token type ${token.type}'),
};

String _dartValue(Token token) {
  switch (token.type) {
    case 'color':
      return 'Color(0x${TokenColor.parse(token.value.toString()).argbHex})';
    case 'dimension':
    case 'number':
      return formatNumber(parseNumber(token.value));
    case 'duration':
      return 'Duration(milliseconds: ${parseDurationMs(token.value)})';
    case 'fontFamily':
      return "'${token.value}'";
    case 'fontWeight':
      return 'FontWeight.w${parseNumber(token.value).toInt()}';
    case 'cubicBezier':
      final points = (token.value as List)
          .map((p) => formatNumber(parseNumber(p as Object)))
          .join(', ');
      return 'Cubic($points)';
    case 'shadow':
      final shadow = token.value as Map<String, Object?>;
      final color = TokenColor.parse(shadow['color']! as String);
      final dx = formatNumber(parseNumber(shadow['offsetX']!));
      final dy = formatNumber(parseNumber(shadow['offsetY']!));
      final blur = formatNumber(parseNumber(shadow['blur']!));
      final spread = formatNumber(parseNumber(shadow['spread'] ?? 0));
      return 'BoxShadow(color: Color(0x${color.argbHex}), '
          'offset: Offset($dx, $dy), blurRadius: $blur, spreadRadius: $spread)';
    default:
      throw StateError('Unhandled token type ${token.type}');
  }
}

// ---------------------------------------------------------------------------
// CSS custom properties (marketing site, docs, Figma plugins)
// ---------------------------------------------------------------------------

String emitCss(List<Token> tokens) {
  final buffer = StringBuffer()
    ..writeln(_banner.replaceAll('//', '/*').replaceAll('\n', ' */\n').trim())
    ..writeln(':root {');
  for (final token in tokens) {
    buffer.writeln('  --np-${token.snakeName.replaceAll('_', '-')}: '
        '${_cssValue(token)};');
  }
  buffer.writeln('}');
  return buffer.toString();
}

String _cssValue(Token token) {
  switch (token.type) {
    case 'color':
      return TokenColor.parse(token.value.toString()).rgbaCss;
    case 'dimension':
      return '${formatNumber(parseNumber(token.value))}px';
    case 'number':
      return formatNumber(parseNumber(token.value));
    case 'duration':
      return '${parseDurationMs(token.value)}ms';
    case 'fontFamily':
      return "'${token.value}', system-ui, sans-serif";
    case 'fontWeight':
      return formatNumber(parseNumber(token.value));
    case 'cubicBezier':
      final points = (token.value as List)
          .map((p) => formatNumber(parseNumber(p as Object)))
          .join(', ');
      return 'cubic-bezier($points)';
    case 'shadow':
      final shadow = token.value as Map<String, Object?>;
      final color = TokenColor.parse(shadow['color']! as String);
      return '${formatNumber(parseNumber(shadow['offsetX']!))}px '
          '${formatNumber(parseNumber(shadow['offsetY']!))}px '
          '${formatNumber(parseNumber(shadow['blur']!))}px '
          '${formatNumber(parseNumber(shadow['spread'] ?? 0))}px '
          '${color.rgbaCss}';
    default:
      throw StateError('Unhandled token type ${token.type}');
  }
}

// ---------------------------------------------------------------------------
// Swift (iOS widgets, App Clip, App Store screenshots)
// ---------------------------------------------------------------------------

String emitSwift(List<Token> tokens) {
  final grouped = <String, List<Token>>{};
  final depths = <String, int>{};
  for (final token in tokens) {
    if (token.type == 'shadow') continue;
    final target = containerFor(token);
    grouped.putIfAbsent(target.container, () => []).add(token);
    depths[target.container] = target.depth;
  }

  final buffer = StringBuffer()
    ..writeln(_banner)
    ..writeln('import SwiftUI')
    ..writeln();

  final names = grouped.keys.toList()..sort();
  for (final name in names) {
    final swiftName = name.replaceFirst('Np', 'NP');
    buffer.writeln('public enum $swiftName {');
    for (final token in grouped[name]!) {
      final member = token.memberName(depths[name]!);
      buffer.writeln('    public static let $member = ${_swiftValue(token)}');
    }
    buffer
      ..writeln('}')
      ..writeln();
  }
  return buffer.toString();
}

String _swiftValue(Token token) {
  switch (token.type) {
    case 'color':
      final c = TokenColor.parse(token.value.toString());
      String channel(int v) => (v / 255).toStringAsFixed(3);
      return 'Color(.sRGB, red: ${channel(c.r)}, green: ${channel(c.g)}, '
          'blue: ${channel(c.b)}, opacity: ${(c.a / 255).toStringAsFixed(3)})';
    case 'dimension':
    case 'number':
      return 'CGFloat(${formatNumber(parseNumber(token.value))})';
    case 'duration':
      return 'Double(${parseDurationMs(token.value) / 1000})';
    case 'fontFamily':
      return '"${token.value}"';
    case 'fontWeight':
      return 'Font.Weight.${_swiftWeight(parseNumber(token.value).toInt())}';
    case 'cubicBezier':
      final points = (token.value as List)
          .map((p) => formatNumber(parseNumber(p as Object)))
          .join(', ');
      return '[$points] as [Double]';
    default:
      throw StateError('Unhandled token type ${token.type}');
  }
}

String _swiftWeight(int weight) => switch (weight) {
  400 => 'regular',
  500 => 'medium',
  600 => 'semibold',
  700 => 'bold',
  _ => 'regular',
};

// ---------------------------------------------------------------------------
// Android resources (native splash screen, notification accents, widgets)
// ---------------------------------------------------------------------------

String emitAndroidColors(List<Token> tokens) {
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln('<!-- GENERATED FILE — DO NOT EDIT. Source: design/tokens -->')
    ..writeln('<resources>');
  for (final token in tokens.where((t) => t.type == 'color')) {
    final color = TokenColor.parse(token.value.toString());
    buffer.writeln(
      '    <color name="np_${token.snakeName.toLowerCase()}">'
      '#${color.argbHex}</color>',
    );
  }
  buffer.writeln('</resources>');
  return buffer.toString();
}

String emitAndroidDimens(List<Token> tokens) {
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln('<!-- GENERATED FILE — DO NOT EDIT. Source: design/tokens -->')
    ..writeln('<resources>');
  for (final token in tokens.where((t) => t.type == 'dimension')) {
    final unit = token.path.first == 'font' ? 'sp' : 'dp';
    buffer.writeln(
      '    <dimen name="np_${token.snakeName.toLowerCase()}">'
      '${formatNumber(parseNumber(token.value))}$unit</dimen>',
    );
  }
  buffer.writeln('</resources>');
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Flat JSON (Figma / Style Dictionary / anything else downstream)
// ---------------------------------------------------------------------------

String emitFlatJson(List<Token> tokens) {
  final map = <String, Object?>{
    r'$comment': 'GENERATED FILE — DO NOT EDIT. Source: design/tokens/*.json',
    for (final token in tokens)
      token.name: {
        'value': token.value,
        'type': token.type,
        if (token.description != null) 'description': token.description,
      },
  };
  return '${const JsonEncoder.withIndent('  ').convert(map)}\n';
}
