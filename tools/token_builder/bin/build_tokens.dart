import 'dart:io';

import 'package:token_builder/src/emitters.dart';
import 'package:token_builder/src/loader.dart';

/// Compiles `design/tokens/*.json` into per-platform source files.
///
/// ```
/// dart run tools/token_builder/bin/build_tokens.dart          # write files
/// dart run tools/token_builder/bin/build_tokens.dart --check  # CI guard
/// ```
///
/// `--check` writes nothing and exits non-zero when a generated file is stale,
/// which is how CI catches "edited the JSON but forgot to regenerate".
Future<void> main(List<String> args) async {
  final checkOnly = args.contains('--check');
  final repoRoot = _findRepoRoot(Directory.current);

  final tokens = TokenLoader(
    Directory('${repoRoot.path}/design/tokens'),
  ).load();

  final outputs = <String, String>{
    'app/lib/design_system/tokens/design_tokens.g.dart': emitDart(tokens),
    'design/build/tokens.css': emitCss(tokens),
    'design/build/Tokens.swift': emitSwift(tokens),
    'design/build/colors.xml': emitAndroidColors(tokens),
    'design/build/dimens.xml': emitAndroidDimens(tokens),
    'design/build/tokens.flat.json': emitFlatJson(tokens),
  };

  var stale = 0;
  for (final entry in outputs.entries) {
    final file = File('${repoRoot.path}/${entry.key}');
    final current = file.existsSync() ? file.readAsStringSync() : null;
    // Dart output goes through `dart format` so it matches what the repo's
    // formatter would produce; otherwise `--check` would fail every time
    // somebody runs `dart format` over lib/.
    final next = entry.key.endsWith('.dart')
        ? _formatDart(entry.value)
        : entry.value.replaceAll('\r\n', '\n');

    if (current?.replaceAll('\r\n', '\n') == next) {
      stdout.writeln('  unchanged  ${entry.key}');
      continue;
    }
    if (checkOnly) {
      stale++;
      stderr.writeln('  STALE      ${entry.key}');
      continue;
    }
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(next);
    stdout.writeln('  written    ${entry.key}');
  }

  stdout.writeln('${tokens.length} tokens processed.');
  if (stale > 0) {
    stderr.writeln(
      '\n$stale generated file(s) are out of date. Run:\n'
      '  dart run tools/token_builder/bin/build_tokens.dart',
    );
    exit(1);
  }
}

/// Runs `dart format` over [source] via a scratch file.
///
/// Shelling out keeps this package dependency-free while still producing output
/// that is byte-identical to what a developer's formatter would write.
String _formatDart(String source) {
  final scratch = Directory.systemTemp.createTempSync('np_tokens');
  final file = File('${scratch.path}/formatted.dart')
    ..writeAsStringSync(source.replaceAll('\r\n', '\n'));

  final result = Process.runSync('dart', [
    'format',
    file.path,
  ], runInShell: true);
  if (result.exitCode != 0) {
    stderr.writeln('dart format failed:\n${result.stderr}');
    scratch.deleteSync(recursive: true);
    exit(3);
  }

  final formatted = file.readAsStringSync().replaceAll('\r\n', '\n');
  scratch.deleteSync(recursive: true);
  return formatted;
}

Directory _findRepoRoot(Directory from) {
  var dir = from.absolute;
  while (true) {
    if (Directory('${dir.path}/design/tokens').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      stderr.writeln('Could not locate the repository root from ${from.path}');
      exit(2);
    }
    dir = parent;
  }
}
