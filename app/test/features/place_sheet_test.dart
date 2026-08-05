import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/data/repository_providers.dart';
import 'package:noplace/domain/entities/auto_check_in.dart';
import 'package:noplace/domain/entities/geo_point.dart';
import 'package:noplace/domain/entities/map_point.dart';
import 'package:noplace/domain/repositories/repositories.dart';
import 'package:noplace/features/places/presentation/place_sheet.dart';

import '../support/pump_app.dart';

/// Remembers what the sheet asked it to do. A test double rather than the real
/// SQLite store: what is under test is the form, not the file format.
class _RecordingRepository implements MapPointRepository {
  final List<MapPoint> added = [];
  final List<MapPoint> updated = [];
  final List<String> removed = [];

  @override
  Future<void> add(MapPoint point) async => added.add(point);

  @override
  Future<void> update(MapPoint point) async => updated.add(point);

  @override
  Future<void> remove(String id) async => removed.add(id);

  @override
  Stream<List<MapPoint>> watch() => const Stream.empty();
}

void main() {
  const benThanh = GeoPoint(10.7725, 106.6980);

  final saved = MapPoint(
    id: 'p1',
    kind: MapPointKind.user,
    location: benThanh,
    createdAt: DateTime(2026, 8, 1),
    label: 'Good bench',
    iconId: 'star',
    stars: 3,
    checkInCount: 3,
    lastCheckInAt: DateTime(2026, 8, 4, 18, 30),
  );

  /// Opens the sheet from a real route, because it pops itself when it is done
  /// and a sheet that is the only route has nothing to pop to.
  Future<_RecordingRepository> open(
    WidgetTester tester, {
    MapPoint? existing,
    Locale locale = const Locale('en'),
    Size surfaceSize = const Size(390, 844),
  }) async {
    final repository = _RecordingRepository();

    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => existing == null
              ? showAddPlaceSheet(context: context, location: benThanh)
              : showPlaceSheet(context: context, place: existing),
          child: const Text('open'),
        ),
      ),
      overrides: [mapPointRepositoryProvider.overrideWithValue(repository)],
      locale: locale,
      surfaceSize: surfaceSize,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return repository;
  }

  group('adding a place', () {
    testWidgets('saves the name, icon, feeling and rating together', (
      tester,
    ) async {
      final repository = await open(tester);

      await tester.enterText(find.byType(TextField), 'Bánh mì on the corner');
      await tester.tap(find.byIcon(Icons.local_cafe_rounded));
      await tester.pump();
      await tester.tap(find.text('Calm'));
      await tester.pump();
      // The fourth star. Every star is hollow until one is picked.
      await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
      await tester.pump();

      await tester.tap(find.text('Save this place'));
      await tester.pumpAndSettle();

      final place = repository.added.single;
      expect(place.label, 'Bánh mì on the corner');
      expect(place.iconId, 'coffee');
      expect(place.moodId, PlaceMood.calm);
      expect(place.stars, 4);
      expect(place.location, benThanh);
      // Saving a place is not being there. The count starts at nothing.
      expect(place.checkInCount, 0);
      // Nobody touched the picker, so the place behaves the way every place
      // did before the picker existed.
      expect(place.autoCheckInEvery, AutoCheckIn.hourly);
      expect(repository.updated, isEmpty);
    });

    testWidgets('an unnamed pin is still a place worth keeping', (
      tester,
    ) async {
      final repository = await open(tester);

      await tester.tap(find.text('Save this place'));
      await tester.pumpAndSettle();

      expect(repository.added.single.label, isEmpty);
      expect(repository.added.single.stars, 0);
    });

    testWidgets('has nothing to check into and nothing to delete', (
      tester,
    ) async {
      await open(tester);

      expect(find.text("I'm here now"), findsNothing);
      expect(find.text('Delete this place'), findsNothing);
      expect(find.textContaining('Checked in'), findsNothing);
    });
  });

  group('a place already saved', () {
    testWidgets('shows how often the player has been there', (tester) async {
      await open(tester, existing: saved);

      expect(find.text('Checked in 3 times'), findsOneWidget);
      // Loosely matched on purpose: how the time itself reads is the
      // formatter's business, and ICU has changed its mind about the space
      // before "PM" before now.
      expect(find.textContaining('Last time Tue at 6:30'), findsOneWidget);
      // The count moves on its own, so the sheet has to say why.
      expect(
        find.text('An hour spent here counts as a check-in on its own.'),
        findsOneWidget,
      );
    });

    testWidgets('checking in counts a visit and keeps the edits', (
      tester,
    ) async {
      final repository = await open(tester, existing: saved);

      await tester.tap(find.byIcon(Icons.star_outline_rounded).at(1));
      await tester.pump();
      await tester.tap(find.text("I'm here now"));
      await tester.pumpAndSettle();

      final place = repository.updated.single;
      expect(place.id, 'p1');
      expect(place.checkInCount, 4);
      expect(place.lastCheckInAt, isNotNull);
      // The rating changed in the same breath as the check-in; losing it to the
      // more obvious button is what stops people editing anything.
      expect(place.stars, 5);
      expect(repository.added, isEmpty);
    });

    testWidgets('saving changes alone leaves the count where it was', (
      tester,
    ) async {
      final repository = await open(tester, existing: saved);

      await tester.enterText(find.byType(TextField), 'The good bench');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(repository.updated.single.label, 'The good bench');
      expect(repository.updated.single.checkInCount, 3);
    });

    testWidgets('deleting hands the place back, so it can be undone', (
      tester,
    ) async {
      final repository = await open(tester, existing: saved);

      await tester.tap(find.text('Delete this place'));
      await tester.pumpAndSettle();

      expect(repository.removed, ['p1']);
    });
  });

  group('auto check-in', () {
    testWidgets('the interval the player picks is what gets saved', (
      tester,
    ) async {
      final repository = await open(tester, existing: saved);

      await tester.tap(find.text('2 hours'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(repository.updated.single.autoCheckInEvery, AutoCheckIn.twoHourly);
    });

    testWidgets('switching it off is a choice that sticks', (tester) async {
      // The one that a `copyWith` built on `??` would quietly drop, which is
      // why "Off" is a duration of zero rather than a null.
      final repository = await open(tester, existing: saved);

      await tester.tap(find.text('Off'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final place = repository.updated.single;
      expect(place.autoCheckInEvery, AutoCheckIn.off);
      expect(place.autoChecksIn, isFalse);
    });

    testWidgets('the note under the count follows the picker immediately', (
      tester,
    ) async {
      await open(tester, existing: saved);

      expect(
        find.text('An hour spent here counts as a check-in on its own.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Off'));
      await tester.pump();

      // Said before it is saved, not after: the player is deciding right now,
      // and "what will this do" is the question the sheet has to answer.
      expect(
        find.text(
          'Only the button counts here — nothing is recorded on its own.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the question mark explains what it will do', (tester) async {
      await open(tester, existing: saved);

      await tester.tap(find.byIcon(Icons.help_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Counting your visits for you'), findsOneWidget);
      expect(find.textContaining('150 m'), findsOneWidget);
      expect(find.textContaining('20 minutes'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      // Closed the tip, not the place. Reading the explanation must not cost
      // the player the edits they were part-way through.
      expect(find.text('Counting your visits for you'), findsNothing);
      expect(find.text('Save changes'), findsOneWidget);
    });
  });

  testWidgets('fits a small screen in Vietnamese', (tester) async {
    // The narrowest phone we support, in the longer of the two languages: five
    // feelings across one row is the part most likely to give.
    await open(
      tester,
      existing: saved,
      locale: const Locale('vi'),
      surfaceSize: const Size(360, 640),
    );

    expect(find.text('Đã điểm danh 3 lần'), findsOneWidget);
    expect(find.text('Mình đang ở đây'), findsOneWidget);
  });
}
