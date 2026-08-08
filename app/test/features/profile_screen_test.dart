import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/data/repository_providers.dart';
import 'package:noplace/domain/entities/explorer_profile.dart';
import 'package:noplace/domain/entities/walk_history.dart';
import 'package:noplace/features/profile/presentation/profile_screen.dart';

import '../support/pump_app.dart';

void main() {
  const walked = ExplorerProfile(
    regionId: 'vn-hcmc',
    regionName: 'TP. Hồ Chí Minh',
    displayName: 'Anh',
    level: 3,
    xp: 3420,
    chartedSquareMeters: 1840000,
    walk: WalkHistory(
      distanceTodayMeters: 4200,
      distanceTotalMeters: 96000,
      streakDays: 6,
      daysWalked: 21,
    ),
    checkInPlaces: 27,
    districtsKnown: 221,
    districts: [
      DistrictProgress(
        id: 'osm-r1',
        name: 'Phường Bến Thành',
        chartedFraction: 0.62,
        chartedSquareMeters: 1200000,
        areaSquareMeters: 1930000,
      ),
      DistrictProgress(
        id: 'osm-r2',
        name: 'Phường Gò Vấp',
        chartedFraction: 0.08,
        chartedSquareMeters: 640000,
        areaSquareMeters: 8000000,
      ),
    ],
  );

  Future<void> pumpProfile(
    WidgetTester tester, {
    ExplorerProfile profile = walked,
    Locale locale = const Locale('en'),
    Size surfaceSize = const Size(390, 844),
  }) async {
    await tester.pumpApp(
      const ProfileScreen(),
      overrides: [explorerProfileProvider.overrideWithValue(profile)],
      locale: locale,
      surfaceSize: surfaceSize,
    );
    await tester.pumpAndSettle();
  }

  group('ProfileScreen', () {
    testWidgets('shows the player and what they have walked', (tester) async {
      await pumpProfile(tester);

      expect(find.text('Anh'), findsOneWidget);
      expect(find.text('Level 3 Explorer · 3420 XP'), findsOneWidget);
      expect(find.text('1.8 km²'), findsOneWidget);
      expect(find.text('uncovered in TP. Hồ Chí Minh'), findsOneWidget);
      expect(find.text('4.2 km'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);
      expect(find.text('6 days'), findsOneWidget);
    });

    testWidgets('lists the districts, most walked first', (tester) async {
      await pumpProfile(tester);

      expect(find.text('Districts · TP. Hồ Chí Minh'), findsOneWidget);
      expect(find.text('2 / 221 districts'), findsOneWidget);
      expect(find.text('Phường Bến Thành'), findsOneWidget);
      expect(find.text('62%'), findsOneWidget);
      expect(find.text('Phường Gò Vấp'), findsOneWidget);
      expect(find.text('8%'), findsOneWidget);
    });

    testWidgets('says the ranking is not available rather than inventing one', (
      tester,
    ) async {
      await pumpProfile(tester);

      expect(find.text('City ranking'), findsOneWidget);
      expect(find.text('Not available yet'), findsOneWidget);
      // Nothing that looks like a position on a leaderboard we do not have.
      expect(find.textContaining('#'), findsNothing);
    });

    testWidgets('offers the maps that exist, current one first', (tester) async {
      await pumpProfile(tester);

      expect(find.text('Maps'), findsOneWidget);
      expect(find.text('TP. Hồ Chí Minh'), findsWidgets);
      expect(find.text('Đồng Nai'), findsOneWidget);
      // Not on the device, and still worth knowing about.
      expect(find.text('Hà Nội'), findsOneWidget);
    });

    testWidgets('a fresh phone reads as empty, not as somebody else', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        profile: const ExplorerProfile(
          regionId: 'vn-hcmc',
          regionName: 'TP. Hồ Chí Minh',
        ),
      );

      expect(find.text('Unnamed explorer'), findsOneWidget);
      expect(find.text('Level 1 Explorer · 0 XP'), findsOneWidget);
      expect(find.text('0.00 km²'), findsOneWidget);
      expect(find.text('0 m'), findsOneWidget);
      expect(find.text('0 days'), findsOneWidget);
      expect(
        find.text('No district data for this map yet.'),
        findsOneWidget,
      );
    });

    testWidgets('says so when the map is cooked but unwalked', (tester) async {
      await pumpProfile(
        tester,
        profile: const ExplorerProfile(
          regionId: 'vn-hcmc',
          regionName: 'TP. Hồ Chí Minh',
          districtsKnown: 221,
        ),
      );

      expect(
        find.text('Walk somewhere to chart your first district.'),
        findsOneWidget,
      );
      expect(find.text('0 / 221 districts'), findsOneWidget);
    });

    testWidgets('renders on a small screen without overflowing', (tester) async {
      // Galaxy S8 logical size — the narrowest device we support.
      await pumpProfile(tester, surfaceSize: const Size(360, 740));

      expect(tester.takeException(), isNull);
    });

    testWidgets('translates the stat captions', (tester) async {
      await pumpProfile(tester, locale: const Locale('vi'));

      expect(find.text('Quãng đường hôm nay'), findsOneWidget);
      expect(find.text('Nơi đã điểm danh'), findsOneWidget);
      expect(find.text('Chuỗi ngày liên tục'), findsOneWidget);
      expect(find.text('Chưa có'), findsOneWidget);
    });
  });
}
