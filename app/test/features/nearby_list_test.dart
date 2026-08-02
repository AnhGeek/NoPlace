import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/data/fake/fake_world_store.dart';
import 'package:noplace/data/repository_providers.dart';
import 'package:noplace/design_system/components/components.dart';
import 'package:noplace/domain/entities/geo_point.dart';
import 'package:noplace/features/map/presentation/widgets/nearby_list.dart';

import '../support/pump_app.dart';

void main() {
  group('NearbyList', () {
    testWidgets('lists the seeded places closest first', (tester) async {
      await tester.pumpApp(NearbyList(onCheckIn: (_) {}));
      await tester.pumpAndSettle();

      final titles = tester
          .widgetList<NpListRow>(find.byType(NpListRow))
          .map((row) => row.title)
          .toList();

      // Bến Thành is ~40 m from the seed position, Phở Hòa ~75 m, Nhà thờ
      // Đức Bà ~95 m. Everything past 500 m is not on the list at all.
      expect(titles.take(3), [
        'Chợ Bến Thành',
        'Phở Hòa Pasteur',
        'Nhà thờ Đức Bà',
      ]);
      // The default reach is 2 km, so Tao Đàn at ~630 m is on the list and
      // Gò Vấp, 7 km away, is not.
      expect(titles, contains('Công viên Tao Đàn'));
      expect(titles, isNot(contains('Lotte Mart Gò Vấp')));
    });

    testWidgets('a place already checked in says so on its name', (
      tester,
    ) async {
      await tester.pumpApp(NearbyList(onCheckIn: (_) {}));
      await tester.pumpAndSettle();

      // Saigon Post Office is the one seeded place marked visited.
      expect(find.text('Saigon Post Office · checked in'), findsOneWidget);
      expect(find.text('Chợ Bến Thành'), findsOneWidget);
    });

    testWidgets('rows out of check-in range are dimmed, not hidden', (
      tester,
    ) async {
      await tester.pumpApp(NearbyList(onCheckIn: (_) {}));
      await tester.pumpAndSettle();

      final rows = tester.widgetList<NpListRow>(find.byType(NpListRow));

      // Both states are present: the check-in radius is 200 m and the list
      // reaches 500 m.
      expect(rows.where((row) => row.dimmed), isNotEmpty);
      expect(rows.where((row) => !row.dimmed), isNotEmpty);

      final dimmed = rows.firstWhere((row) => row.dimmed);
      expect(dimmed.onTap, isNull);
      expect(dimmed.subtitle, contains('walk closer to check in'));
    });

    testWidgets('tapping a row in range asks for a check-in', (tester) async {
      String? checkedIn;
      await tester.pumpApp(
        NearbyList(onCheckIn: (place) => checkedIn = place.id),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chợ Bến Thành'));
      await tester.pumpAndSettle();

      expect(checkedIn, 'place-ben-thanh');
    });

    testWidgets('says so when there is nothing within walking distance', (
      tester,
    ) async {
      final store = FakeWorldStore();
      await tester.pumpApp(
        NearbyList(onCheckIn: (_) {}),
        overrides: [fakeWorldStoreProvider.overrideWithValue(store)],
      );
      await tester.pumpAndSettle();

      // Walk to the far side of the city, away from every seeded place.
      store.moveTo(const GeoPoint(10.9000, 106.9000));
      await tester.pumpAndSettle();

      expect(find.byType(NpListRow), findsNothing);
      expect(find.text('Nothing mapped here yet'), findsOneWidget);
    });
  });
}
