import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the translations.
///
/// A missing Vietnamese string does not crash — it silently falls back to
/// English, which is exactly the kind of bug nobody reports and everybody
/// notices. This test fails the build instead.
void main() {
  Map<String, Object?> readArb(String locale) {
    final file = File('lib/l10n/arb/app_$locale.arb');
    if (!file.existsSync()) {
      throw StateError('${file.path} is missing');
    }
    return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  }

  Set<String> messageKeys(Map<String, Object?> arb) =>
      arb.keys.where((key) => !key.startsWith('@')).toSet();

  final english = readArb('en');
  final vietnamese = readArb('vi');

  test('every English message has a Vietnamese translation', () {
    final missing = messageKeys(english).difference(messageKeys(vietnamese));
    expect(missing, isEmpty, reason: 'Missing vi translations: $missing');
  });

  test('Vietnamese has no keys the template does not define', () {
    final extra = messageKeys(vietnamese).difference(messageKeys(english));
    expect(extra, isEmpty, reason: 'Stale vi keys: $extra');
  });

  test('every English message is documented', () {
    final undocumented = messageKeys(
      english,
    ).where((key) => !english.containsKey('@$key')).toList();
    expect(
      undocumented,
      isEmpty,
      reason: 'Add an @-description for: $undocumented',
    );
  });

  test('every declared placeholder is used in both locales', () {
    // Scanning the message text with a regex would trip over ICU sub-messages
    // (`{visited, select, never{never visited} …}`), so the declared
    // placeholders in the @-metadata are the source of truth.
    for (final key in messageKeys(english)) {
      final meta = english['@$key'] as Map<String, Object?>?;
      final declared = (meta?['placeholders'] as Map<String, Object?>?)?.keys;
      if (declared == null) continue;

      for (final name in declared) {
        expect(
          english[key]! as String,
          contains('{$name'),
          reason: 'en "$key" declares {$name} but never uses it',
        );
        expect(
          vietnamese[key]! as String,
          contains('{$name'),
          reason: 'vi "$key" is missing the {$name} placeholder',
        );
      }
    }
  });
}
