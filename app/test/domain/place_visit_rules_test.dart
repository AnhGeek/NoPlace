import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/domain/entities/auto_check_in.dart';
import 'package:noplace/domain/entities/geo_point.dart';
import 'package:noplace/domain/entities/map_point.dart';
import 'package:noplace/domain/entities/place_visit.dart';
import 'package:noplace/domain/rules/place_visit_rules.dart';

/// The rule that turns sitting still into a check-in.
///
/// Written against a moved clock rather than a moved player, which is the whole
/// reason the rule is a pure function: the alternative is three hours in a café
/// per assertion.
void main() {
  const cafe = GeoPoint(10.7725, 106.6980);

  /// ~90 m north of the café: inside the radius, and far enough out to be a
  /// realistic urban fix rather than the same coordinate twice.
  const nextDoor = GeoPoint(10.773310, 106.6980);

  /// ~1.5 km away — a different neighbourhood by any measure.
  const acrossTown = GeoPoint(10.7860, 106.6980);

  final opened = DateTime(2026, 8, 5, 9);

  MapPoint place({
    DateTime? startedAt,
    DateTime? seenAt,
    int checkIns = 0,
    Duration every = AutoCheckIn.hourly,
  }) => MapPoint(
    id: 'p1',
    kind: MapPointKind.user,
    location: cafe,
    createdAt: opened,
    label: 'The café',
    checkInCount: checkIns,
    stayStartedAt: startedAt,
    stayLastSeenAt: seenAt,
    autoCheckInEvery: every,
  );

  group('arriving', () {
    test('a fix nearby starts a stay but awards nothing', () {
      final updated = PlaceVisitRules.applyFix(
        place(),
        position: nextDoor,
        now: opened,
      );

      expect(updated, isNotNull);
      expect(updated!.stayStartedAt, opened);
      expect(updated.stayLastSeenAt, opened);
      // Walking past is not a visit. Only the hour, or the button, is.
      expect(updated.checkInCount, 0);
    });

    test('a fix somewhere else changes nothing at all', () {
      final updated = PlaceVisitRules.applyFix(
        place(startedAt: opened, seenAt: opened),
        position: acrossTown,
        now: opened.add(const Duration(minutes: 5)),
      );

      // Not "cleared" — null. Leaving must not cost a database write, or every
      // GPS wobble in the city would be one.
      expect(updated, isNull);
    });
  });

  group('the hour', () {
    test('an hour on the spot is one check-in', () {
      final updated = PlaceVisitRules.applyFix(
        place(
          startedAt: opened,
          seenAt: opened.add(const Duration(minutes: 58)),
        ),
        position: cafe,
        now: opened.add(const Duration(minutes: 61)),
      );

      expect(updated!.checkInCount, 1);
      expect(updated.lastCheckInAt, opened.add(const Duration(minutes: 61)));
    });

    test('fifty-nine minutes is not', () {
      final updated = PlaceVisitRules.applyFix(
        place(
          startedAt: opened,
          seenAt: opened.add(const Duration(minutes: 55)),
        ),
        position: cafe,
        now: opened.add(const Duration(minutes: 59)),
      );

      // Inside the heartbeat window too, so there is nothing to write.
      expect(updated, isNull);
    });

    test('a whole afternoon is one check-in per hour', () {
      // A stay kept alive by the heartbeat all afternoon: last confirmed five
      // minutes ago, started three and a half hours ago.
      final updated = PlaceVisitRules.applyFix(
        place(
          startedAt: opened,
          seenAt: opened.add(const Duration(hours: 3, minutes: 25)),
        ),
        position: cafe,
        now: opened.add(const Duration(hours: 3, minutes: 30)),
      );

      expect(updated!.checkInCount, 3);
      // The half hour is kept rather than thrown away, so the fourth check-in
      // lands on the hour and not thirty minutes late.
      expect(updated.stayStartedAt, opened.add(const Duration(hours: 3)));
    });

    test('the next hour has to be earned again', () {
      final paid = PlaceVisitRules.applyFix(
        place(
          startedAt: opened,
          seenAt: opened.add(const Duration(minutes: 58)),
        ),
        position: cafe,
        now: opened.add(const Duration(minutes: 60)),
      )!;

      final again = PlaceVisitRules.applyFix(
        paid,
        position: cafe,
        now: opened.add(const Duration(minutes: 63)),
      );

      expect(paid.checkInCount, 1);
      expect(again, isNull);
    });
  });

  group('what ends a stay', () {
    test('a gap longer than twenty minutes starts a new one', () {
      // Fifty minutes in, the player left for half an hour and came back.
      final updated = PlaceVisitRules.applyFix(
        place(
          startedAt: opened,
          seenAt: opened.add(const Duration(minutes: 50)),
        ),
        position: cafe,
        now: opened.add(const Duration(minutes: 85)),
      );

      expect(updated!.checkInCount, 0);
      expect(updated.stayStartedAt, opened.add(const Duration(minutes: 85)));
    });

    test('a stay nobody has vouched for since Friday pays out nothing', () {
      // The app was killed at the office on Friday evening and opened there
      // again on Monday. Three days of wall clock, no sightings in between.
      final updated = PlaceVisitRules.applyFix(
        place(startedAt: opened, seenAt: opened.add(const Duration(hours: 8))),
        position: cafe,
        now: opened.add(const Duration(days: 3)),
      );

      expect(updated!.checkInCount, 0);
      expect(updated.stayStartedAt, opened.add(const Duration(days: 3)));
    });

    test('one drifting fix does not, because leaving is never recorded', () {
      final stay = place(
        startedAt: opened,
        seenAt: opened.add(const Duration(minutes: 58)),
      );

      // A fix that landed across town — GPS in a city does this — is ignored…
      expect(
        PlaceVisitRules.applyFix(
          stay,
          position: acrossTown,
          now: opened.add(const Duration(minutes: 59)),
        ),
        isNull,
      );

      // …so the hour that was nearly up still pays out.
      final updated = PlaceVisitRules.applyFix(
        stay,
        position: cafe,
        now: opened.add(const Duration(minutes: 61)),
      );
      expect(updated!.checkInCount, 1);
    });

    test('a clock that jumps backwards restarts the stay', () {
      final updated = PlaceVisitRules.applyFix(
        place(startedAt: opened, seenAt: opened.add(const Duration(hours: 5))),
        position: cafe,
        now: opened,
      );

      expect(updated!.checkInCount, 0);
      expect(updated.stayStartedAt, opened);
    });
  });

  group('writes', () {
    test('an ongoing stay is written back no more than every five minutes', () {
      final quiet = PlaceVisitRules.applyFix(
        place(
          startedAt: opened,
          seenAt: opened.add(const Duration(minutes: 4)),
        ),
        position: cafe,
        now: opened.add(const Duration(minutes: 6)),
      );
      expect(quiet, isNull);

      final heartbeat = PlaceVisitRules.applyFix(
        place(startedAt: opened, seenAt: opened),
        position: cafe,
        now: opened.add(const Duration(minutes: 6)),
      );
      expect(heartbeat!.stayLastSeenAt, opened.add(const Duration(minutes: 6)));
      expect(heartbeat.checkInCount, 0);
    });
  });

  group('tapping the button', () {
    test('counts a visit and restarts the hour', () {
      final now = opened.add(const Duration(minutes: 50));
      final updated = PlaceVisitRules.checkIn(
        place(startedAt: opened, seenAt: now, checkIns: 2),
        now: now,
      );

      expect(updated.checkInCount, 3);
      expect(updated.lastCheckInAt, now);
      // Otherwise the fifty minutes already on the clock would pay out again
      // ten minutes later, and the same sitting would count twice.
      expect(updated.stayStartedAt, now);
    });

    test('works at a place that never counts anything on its own', () {
      final now = opened.add(const Duration(minutes: 50));
      final updated = PlaceVisitRules.checkIn(
        place(every: AutoCheckIn.off, checkIns: 1),
        now: now,
      );

      // "Off" is about the *unattended* hour. Somebody who says they are here
      // is still here.
      expect(updated.checkInCount, 2);
      expect(updated.lastCheckInAt, now);
    });
  });

  group('the interval the player picked', () {
    test('half an hour pays out twice as often', () {
      final updated = PlaceVisitRules.applyFix(
        place(
          startedAt: opened,
          seenAt: opened.add(const Duration(minutes: 28)),
          every: AutoCheckIn.halfHourly,
        ),
        position: cafe,
        now: opened.add(const Duration(minutes: 31)),
      );

      expect(updated!.checkInCount, 1);
      // On an hourly place the same sitting would still be waiting.
      expect(
        PlaceVisitRules.applyFix(
          place(
            startedAt: opened,
            seenAt: opened.add(const Duration(minutes: 28)),
          ),
          position: cafe,
          now: opened.add(const Duration(minutes: 31)),
        )?.checkInCount,
        anyOf(isNull, 0),
      );
    });

    test('two hours does not pay out after one', () {
      // Last seen six minutes ago, so the heartbeat is due and there *is*
      // something to write — which is what makes "nothing was awarded"
      // an assertion rather than an accident of the throttle.
      final updated = PlaceVisitRules.applyFix(
        place(
          startedAt: opened,
          seenAt: opened.add(const Duration(minutes: 55)),
          every: AutoCheckIn.twoHourly,
        ),
        position: cafe,
        now: opened.add(const Duration(minutes: 61)),
      );

      // The stay is still alive — it is just not worth anything yet.
      expect(updated!.checkInCount, 0);
      expect(updated.stayStartedAt, opened);
      expect(updated.stayLastSeenAt, opened.add(const Duration(minutes: 61)));
    });

    test('a whole afternoon at a two-hour place is two check-ins', () {
      final updated = PlaceVisitRules.applyFix(
        place(
          startedAt: opened,
          seenAt: opened.add(const Duration(hours: 4, minutes: 55)),
          every: AutoCheckIn.twoHourly,
        ),
        position: cafe,
        now: opened.add(const Duration(hours: 5)),
      );

      expect(updated!.checkInCount, 2);
      expect(updated.stayStartedAt, opened.add(const Duration(hours: 4)));
    });

    test('off writes nothing at all, however long you sit there', () {
      // Home, where the player has switched it off: three hours on the spot,
      // and not one database write to show for it.
      expect(
        PlaceVisitRules.applyFix(
          place(
            startedAt: opened,
            seenAt: opened.add(const Duration(hours: 2, minutes: 58)),
            every: AutoCheckIn.off,
          ),
          position: cafe,
          now: opened.add(const Duration(hours: 3)),
        ),
        isNull,
      );

      // Not even the arrival that would normally start a stay.
      expect(
        PlaceVisitRules.applyFix(
          place(every: AutoCheckIn.off),
          position: nextDoor,
          now: opened,
        ),
        isNull,
      );
    });

    test('switching it back on starts a fresh stay, not a backdated one', () {
      // The stay fields left over from before it was switched off are stale by
      // days. Paying them out on the first fix after switching on would hand
      // over a weekend nobody spent.
      final updated = PlaceVisitRules.applyFix(
        place(
          startedAt: opened,
          seenAt: opened.add(const Duration(minutes: 10)),
        ),
        position: cafe,
        now: opened.add(const Duration(days: 2)),
      );

      expect(updated!.checkInCount, 0);
      expect(updated.stayStartedAt, opened.add(const Duration(days: 2)));
    });
  });

  group('a place the world came with', () {
    test('keeps its history through the same rule', () {
      const benThanh = PlaceVisit(placeId: 'place-ben-thanh', checkInCount: 6);
      final now = DateTime(2026, 8, 5, 14, 20);

      final updated = PlaceVisitRules.visited(benThanh, now: now);

      expect(updated.placeId, 'place-ben-thanh');
      expect(updated.checkInCount, 7);
      expect(updated.lastCheckInAt, now);
      expect(updated.hasVisited, isTrue);
    });

    test('starts at nobody having been there', () {
      const fresh = PlaceVisit.none('place-tao-dan');

      expect(fresh.checkInCount, 0);
      expect(fresh.hasVisited, isFalse);
      expect(fresh.lastCheckInAt, isNull);
    });
  });
}
