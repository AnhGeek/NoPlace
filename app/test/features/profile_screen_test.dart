import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/features/profile/presentation/profile_screen.dart';

import '../support/pump_app.dart';

void main() {
  group('ProfileScreen', () {
    testWidgets('shows the player, the headline stat and the tiles', (
      tester,
    ) async {
      await tester.pumpApp(const ProfileScreen());
      await tester.pumpAndSettle();

      expect(find.text('Wayfarer_01'), findsOneWidget);
      expect(find.text('Level 4 Explorer · 340 XP'), findsOneWidget);
      expect(find.text('38%'), findsOneWidget);
      expect(find.text('of the city charted'), findsOneWidget);
      expect(find.text('4.2 km'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);
      expect(find.text('6 days'), findsOneWidget);
      expect(find.text("You're #125 of 430 explorers"), findsOneWidget);
    });

    testWidgets('renders on a small screen without overflowing', (
      tester,
    ) async {
      // Galaxy S8 logical size — the narrowest device we support.
      await tester.pumpApp(
        const ProfileScreen(),
        surfaceSize: const Size(360, 740),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('translates the stat captions', (tester) async {
      await tester.pumpApp(const ProfileScreen(), locale: const Locale('vi'));
      await tester.pumpAndSettle();

      expect(find.text('Quãng đường hôm nay'), findsOneWidget);
      expect(find.text('Nơi đã điểm danh'), findsOneWidget);
      expect(find.text('Chuỗi ngày liên tục'), findsOneWidget);
    });
  });
}
