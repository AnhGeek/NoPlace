import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/design_system/components/components.dart';
import 'package:noplace/features/logs/presentation/logs_screen.dart';

import '../support/pump_app.dart';

void main() {
  group('LogsScreen', () {
    testWidgets('renders the seeded log in English', (tester) async {
      await tester.pumpApp(const LogsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Explorer Logs'), findsOneWidget);
      expect(find.text('2 / 12 districts'), findsOneWidget);
      expect(find.text('District 1'), findsOneWidget);
      expect(find.text('Saigon Post Office'), findsOneWidget);
      expect(find.text('Unknown site'), findsOneWidget);
      // Two locked rows, both masked.
      expect(find.text('???'), findsNWidgets(2));
    });

    testWidgets('renders in Vietnamese', (tester) async {
      await tester.pumpApp(const LogsScreen(), locale: const Locale('vi'));
      await tester.pumpAndSettle();

      expect(find.text('Nhật ký khám phá'), findsOneWidget);
      expect(find.text('2 / 12 quận'), findsOneWidget);
      expect(find.text('Địa điểm lạ'), findsOneWidget);
    });

    testWidgets('switches to the quest list', (tester) async {
      await tester.pumpApp(const LogsScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quests'));
      await tester.pumpAndSettle();

      expect(find.text('Reveal the unknown site'), findsOneWidget);
      expect(find.text('Walk 5 km today'), findsOneWidget);
      expect(find.text('Enter a new district'), findsOneWidget);
      expect(find.text('Night wanderer'), findsOneWidget);
    });

    testWidgets('locked rows are dimmed, not hidden', (tester) async {
      await tester.pumpApp(const LogsScreen());
      await tester.pumpAndSettle();

      final locked = tester
          .widgetList<NpListRow>(find.byType(NpListRow))
          .where((row) => row.dimmed);

      expect(locked, hasLength(2));
    });
  });
}
