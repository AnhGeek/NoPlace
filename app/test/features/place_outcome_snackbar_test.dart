import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/domain/entities/geo_point.dart';
import 'package:noplace/domain/entities/map_point.dart';
import 'package:noplace/features/map/presentation/map_screen.dart';
import 'package:noplace/features/places/presentation/place_sheet.dart';
import 'package:noplace/l10n/l10n.dart';

import '../support/pump_app.dart';

/// What the map says once the place sheet has closed.
///
/// The bug this is here for: a `SnackBar` given a `SnackBarAction` defaults to
/// `persist: action != null`, so the undo offered after a deletion kept the bar
/// on screen for ever. It sat over the map until the app was restarted, and the
/// only ways out were tapping Undo — which is the opposite of what somebody who
/// meant the deletion wants — or swiping a bar most people do not know is
/// swipeable.
void main() {
  final place = MapPoint(
    id: 'p1',
    kind: MapPointKind.user,
    location: const GeoPoint(10.7725, 106.6980),
    createdAt: DateTime(2026, 8, 1),
    label: 'Good bench',
  );

  Future<void> announce(WidgetTester tester, PlaceSheetOutcome outcome) async {
    var undone = false;

    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            placeOutcomeSnackBar(
              result: PlaceSheetResult(outcome, place),
              l10n: context.l10n,
              onUndo: () => undone = true,
            ),
          ),
          child: const Text('announce'),
        ),
      ),
    );

    await tester.tap(find.text('announce'));
    await tester.pump();

    // The dismiss timer is only armed once the entrance animation has
    // completed — `ScaffoldMessengerState` starts it from its own `build`, and
    // only in the frame where the controller reports completed. Time advanced
    // before that point buys nothing, which is exactly how a test can miss
    // this bug entirely.
    await tester.pump(const Duration(seconds: 1));
    expect(undone, isFalse);
  }

  testWidgets('a deletion offers the way back, and then gets out of the way', (
    tester,
  ) async {
    await announce(tester, PlaceSheetOutcome.deleted);

    expect(find.text('Good bench deleted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // Long enough to read the name and change your mind. Four seconds is not.
    await tester.pump(const Duration(seconds: 6));
    expect(
      find.text('Undo'),
      findsOneWidget,
      reason: 'the undo window must outlast a moment of doubt',
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(
      find.text('Good bench deleted'),
      findsNothing,
      reason: 'a message with an action still has to leave on its own',
    );
  });

  testWidgets('saving says so and leaves, with nothing to undo', (
    tester,
  ) async {
    await announce(tester, PlaceSheetOutcome.saved);

    expect(find.text('Good bench saved'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Good bench saved'), findsNothing);
  });
}
