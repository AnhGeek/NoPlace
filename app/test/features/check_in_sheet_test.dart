import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/data/repository_providers.dart';
import 'package:noplace/domain/entities/geo_point.dart';
import 'package:noplace/domain/entities/place.dart';
import 'package:noplace/domain/entities/place_visit.dart';
import 'package:noplace/domain/repositories/repositories.dart';
import 'package:noplace/features/check_in/presentation/check_in_sheet.dart';

import '../support/pump_app.dart';

/// A visit history held in memory. A test double rather than the SQLite store,
/// because what is under test is what the sheet says, not what the file holds.
class _FakeVisits implements PlaceVisitRepository {
  _FakeVisits([Map<String, PlaceVisit>? seed]) : _visits = {...?seed};

  final Map<String, PlaceVisit> _visits;

  @override
  PlaceVisit of(String placeId) => _visits[placeId] ?? PlaceVisit.none(placeId);

  @override
  Future<void> save(PlaceVisit visit) async => _visits[visit.placeId] = visit;

  @override
  Stream<Map<String, PlaceVisit>> watch() => Stream.value(_visits);
}

void main() {
  const benThanh = Place(
    id: 'place-ben-thanh',
    name: 'Chợ Bến Thành',
    category: PlaceCategory.market,
    location: GeoPoint(10.77286, 106.69800),
    districtId: 'district-1',
    visited: true,
  );

  Future<void> open(
    WidgetTester tester, {
    required Place place,
    PlaceVisit? visit,
  }) async {
    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showCheckInSheet(context: context, place: place),
          child: const Text('open'),
        ),
      ),
      overrides: [
        placeVisitRepositoryProvider.overrideWithValue(
          _FakeVisits(visit == null ? null : {visit.placeId: visit}),
        ),
      ],
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a place the world came with shows its own history', (
    tester,
  ) async {
    await open(
      tester,
      place: benThanh,
      visit: PlaceVisit(
        placeId: 'place-ben-thanh',
        checkInCount: 7,
        lastCheckInAt: DateTime(2026, 8, 4, 18, 30),
      ),
    );

    expect(find.text('Chợ Bến Thành'), findsOneWidget);
    expect(find.text('Checked in 7 times'), findsOneWidget);
    // Loosely matched: how the time itself reads is the formatter's business.
    expect(find.textContaining('Last time Tue at 6:30'), findsOneWidget);
  });

  testWidgets('a place nobody has been to says nothing about visits', (
    tester,
  ) async {
    // A card reading "no check-ins yet" above a button offering to make one is
    // noise, and it would sit there for most places on the map.
    await open(tester, place: benThanh.copyWith(visited: false));

    expect(find.text('Check in here'), findsOneWidget);
    expect(find.textContaining('Checked in'), findsNothing);
    expect(find.textContaining('No check-ins yet'), findsNothing);
  });
}
