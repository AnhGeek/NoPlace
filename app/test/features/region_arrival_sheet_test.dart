import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/data/local/region_catalogue.dart';
import 'package:noplace/data/repository_providers.dart';
import 'package:noplace/features/map/presentation/widgets/region_arrival_sheet.dart';

import '../support/pump_app.dart';

void main() {
  group('RegionArrivalSheet', () {
    testWidgets('names the region the player has just walked into', (
      tester,
    ) async {
      await tester.pumpApp(
        const RegionArrivalSheet(arrived: RegionCatalogue.dongNai),
      );

      expect(find.text("You've reached Đồng Nai"), findsOneWidget);
      // Every region we have a map for is offered, not only the one resolved.
      expect(find.text('TP. Hồ Chí Minh'), findsOneWidget);
      expect(find.text('Đồng Nai'), findsOneWidget);
      expect(find.text('Hà Nội'), findsOneWidget);
    });

    testWidgets('says which maps are actually on the phone', (tester) async {
      await tester.pumpApp(
        const RegionArrivalSheet(arrived: RegionCatalogue.dongNai),
      );

      // The two bundled packs, and Hà Nội which is download-only. Offering a
      // region with no pack would select to an empty map.
      expect(find.text('On this phone · works offline'), findsNWidgets(2));
      expect(find.text('Not on this phone yet'), findsOneWidget);
    });

    testWidgets('a pick becomes the region the map opens, and closes', (
      tester,
    ) async {
      // Opened as a real modal route rather than mounted bare: the sheet's
      // button pops itself, and a sheet that is the only route has nothing to
      // pop to.
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showRegionArrivalSheet(
              context: context,
              arrived: RegionCatalogue.dongNai,
            ),
            child: const Text('open'),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.text('open')),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('TP. Hồ Chí Minh'));
      await tester.pump();
      await tester.tap(find.text('Walk here'));
      await tester.pumpAndSettle();

      expect(container.read(regionPackSourceProvider), RegionCatalogue.hcmc);
      expect(find.byType(RegionArrivalSheet), findsNothing);
    });
  });
}
