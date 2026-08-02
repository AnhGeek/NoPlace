import 'dart:convert';
import 'dart:io';

import 'token.dart';

/// Reads every `*.json` file in [directory], merges them into one tree and
/// flattens it into resolved [Token]s.
///
/// The files follow the W3C Design Tokens Community Group draft format:
/// a node is a *token* when it carries `$value`, otherwise it is a *group*.
/// `$type` is inherited from the closest ancestor that declares it, and a
/// string value of the form `{a.b.c}` is an alias to another token.
class TokenLoader {
  TokenLoader(this.directory);

  final Directory directory;

  List<Token> load() {
    final files =
        directory
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    if (files.isEmpty) {
      throw StateError('No token files found in ${directory.path}');
    }

    final merged = <String, Object?>{};
    for (final file in files) {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?>) {
        throw FormatException('${file.path} must contain a JSON object');
      }
      _deepMerge(merged, decoded, file.path);
    }

    final raw = <String, _RawToken>{};
    _walk(merged, const [], null, raw);

    final resolved = <String, Token>{};
    for (final entry in raw.entries) {
      resolved[entry.key] = _resolve(entry.key, raw, resolved, <String>{});
    }

    final tokens = resolved.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return tokens;
  }

  void _deepMerge(
    Map<String, Object?> target,
    Map<String, Object?> source,
    String origin,
  ) {
    for (final entry in source.entries) {
      final existing = target[entry.key];
      final incoming = entry.value;
      if (existing is Map<String, Object?> && incoming is Map<String, Object?>) {
        _deepMerge(existing, incoming, origin);
      } else if (existing != null && !entry.key.startsWith(r'$')) {
        throw StateError('Duplicate token "${entry.key}" redefined by $origin');
      } else {
        target[entry.key] = incoming;
      }
    }
  }

  void _walk(
    Map<String, Object?> node,
    List<String> path,
    String? inheritedType,
    Map<String, _RawToken> out,
  ) {
    final type = node[r'$type'] as String? ?? inheritedType;

    if (node.containsKey(r'$value')) {
      if (type == null) {
        throw StateError('Token ${path.join('.')} has no \$type');
      }
      out[path.join('.')] = _RawToken(
        path: path,
        type: type,
        value: node[r'$value']!,
        description: node[r'$description'] as String?,
      );
      return;
    }

    for (final entry in node.entries) {
      if (entry.key.startsWith(r'$')) continue;
      final child = entry.value;
      if (child is! Map<String, Object?>) {
        throw FormatException('Unexpected leaf at ${[...path, entry.key]}');
      }
      _walk(child, [...path, entry.key], type, out);
    }
  }

  Token _resolve(
    String name,
    Map<String, _RawToken> raw,
    Map<String, Token> resolved,
    Set<String> seen,
  ) {
    final cached = resolved[name];
    if (cached != null) return cached;
    if (!seen.add(name)) {
      throw StateError('Circular token alias: ${seen.join(' -> ')} -> $name');
    }

    final token = raw[name];
    if (token == null) throw StateError('Unknown token alias "$name"');

    var value = token.value;
    if (value is String && value.startsWith('{') && value.endsWith('}')) {
      final target = value.substring(1, value.length - 1);
      value = _resolve(target, raw, resolved, seen).value;
    }

    final result = Token(
      path: token.path,
      type: token.type,
      value: value,
      description: token.description,
    );
    resolved[name] = result;
    return result;
  }
}

class _RawToken {
  _RawToken({
    required this.path,
    required this.type,
    required this.value,
    this.description,
  });

  final List<String> path;
  final String type;
  final Object value;
  final String? description;
}
