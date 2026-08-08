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
    DateTime? lastCheckInAt,
    int checkIns = 0,
    Duration every = AutoCheckIn.hourly,
  }) => MapPoint(
    id: 'p1',
    kind: MapPointKind.user,
    location: cafe,
    createdAt: opened,
    label: 'The café',
    checkInCount: checkIns,
    lastCheckInAt: lastCheckInAt,
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

    test('changing the interval restarts the wait rather than backdating it', () {
      // Once a day keeps a stay running from the moment the player arrived, so
      // a place they have been sitting in since nine has a stay nearly three
      // hours old by the time they switch it to hourly. Read straight, that is
      // two check-ins on the next fix for a morning spent under a rule that
      // pays once.
      final switched = opened.add(const Duration(hours: 2, minutes: 42));
      final seen = switched.subtract(const Duration(minutes: 2));
      final before = place(
        startedAt: opened,
        seenAt: seen,
        lastCheckInAt: opened,
        checkIns: 1,
        every: AutoCheckIn.daily,
      );

      final changed = PlaceVisitRules.applyIntervalChange(
        before.copyWith(autoCheckInEvery: AutoCheckIn.hourly),
        now: switched,
      );

      expect(changed.checkInCount, 1);
      expect(changed.stayStartedAt, switched);
      // Whether the player is still standing here is the GPS's business.
      expect(changed.stayLastSeenAt, seen);

      // The fix that used to pay out the morning, three minutes later.
      final soonAfter = PlaceVisitRules.applyFix(
        changed,
        position: cafe,
        now: switched.add(const Duration(minutes: 3)),
      );
      expect(soonAfter?.checkInCount, anyOf(isNull, 1));

      // And a whole hour after the change, exactly one — which is what the
      // player asked for when they picked it.
      final anHourOn = PlaceVisitRules.applyFix(
        changed.copyWith(
          stayLastSeenAt: switched.add(const Duration(minutes: 58)),
        ),
        position: cafe,
        now: switched.add(const Duration(hours: 1)),
      );
      expect(anHourOn!.checkInCount, 2);
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

  group('once a day', () {
    MapPoint daily({
      DateTime? lastCheckInAt,
      DateTime? seenAt,
      int checkIns = 0,
    }) => place(
      every: AutoCheckIn.daily,
      lastCheckInAt: lastCheckInAt,
      seenAt: seenAt,
      startedAt: seenAt == null ? null : opened,
      checkIns: checkIns,
    );

    test('turning up is the whole condition — no waiting', () {
      // The one option that pays out on the first fix. Everywhere else this
      // same call starts a stay worth nothing.
      final updated = PlaceVisitRules.applyFix(
        daily(),
        position: nextDoor,
        now: opened,
      );

      expect(updated!.checkInCount, 1);
      expect(updated.lastCheckInAt, opened);
      expect(updated.stayStartedAt, opened);
    });

    test('a second visit the same day is not a second check-in', () {
      // Out for lunch and back again. One line for the day is the promise.
      final afternoon = opened.add(const Duration(hours: 6));
      final updated = PlaceVisitRules.applyFix(
        daily(lastCheckInAt: opened, checkIns: 1),
        position: cafe,
        now: afternoon,
      );

      expect(updated?.checkInCount, anyOf(isNull, 1));
      expect(updated?.lastCheckInAt, anyOf(isNull, opened));
    });

    test('standing there all day is still one check-in', () {
      // Eleven hours without moving. An hourly place would have paid eleven
      // times over; this one said its piece this morning.
      final lateEvening = DateTime(2026, 8, 5, 20);
      final updated = PlaceVisitRules.applyFix(
        daily(
          lastCheckInAt: opened,
          seenAt: lateEvening.subtract(const Duration(minutes: 6)),
          checkIns: 1,
        ),
        position: cafe,
        now: lateEvening,
      );

      // The heartbeat is due, so there is a write — it just isn't a check-in.
      expect(updated!.checkInCount, 1);
      expect(updated.stayLastSeenAt, lateEvening);
    });

    test('the next calendar day counts again', () {
      // Ten past midnight: eight hours after the last one, and a new day. The
      // rolling-window version of this rule would refuse it.
      final justAfterMidnight = DateTime(2026, 8, 6, 0, 10);
      final updated = PlaceVisitRules.applyFix(
        daily(
          lastCheckInAt: DateTime(2026, 8, 5, 16),
          seenAt: DateTime(2026, 8, 5, 16),
          checkIns: 1,
        ),
        position: cafe,
        now: justAfterMidnight,
      );

      expect(updated!.checkInCount, 2);
      expect(updated.lastCheckInAt, justAfterMidnight);
    });

    test('a morning arrival is not refused for being early the next day', () {
      // 08:55 today after 09:00 yesterday — 23 hours 55 minutes. The commute
      // that a rolling day would drop roughly once a week.
      final nextMorning = DateTime(2026, 8, 6, 8, 55);
      final updated = PlaceVisitRules.applyFix(
        daily(lastCheckInAt: opened, seenAt: opened, checkIns: 1),
        position: cafe,
        now: nextMorning,
      );

      expect(updated!.checkInCount, 2);
    });

    test('tapping the button uses up the day', () {
      // A deliberate check-in this morning, then a fix at lunchtime. Counting
      // that would be the same arrival recorded twice.
      final updated = PlaceVisitRules.applyFix(
        PlaceVisitRules.checkIn(daily(), now: opened),
        position: cafe,
        now: opened.add(const Duration(hours: 3)),
      );

      expect(updated?.checkInCount, anyOf(isNull, 1));
    });

    test('walking past the other side of town counts nothing', () {
      expect(
        PlaceVisitRules.applyFix(daily(), position: acrossTown, now: opened),
        isNull,
      );
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
      expect(fresh.isClaimed, isFalse);
      expect(fresh.lastCheckInAt, isNull);
    });
  });

  // The whole reason `claimedAt` exists. The first deliberate check-in at a
  // world place pays double, and turning `Place.autoCheckIn` on must not be a
  // way to lose that without noticing.
  group('the first-visit bonus', () {
    const benThanh = PlaceVisit.none('place-ben-thanh');
    final noon = DateTime(2026, 8, 5, 12);

    test('an hour spent nearby counts as a visit but does not claim it', () {
      // An hour of sitting still, as the app actually sees it: the arrival, the
      // heartbeat keeping the stay vouched for, and the fix that tips it over.
      var visit = PlaceVisitRules.advance(
        benThanh,
        distanceMeters: 40,
        every: AutoCheckIn.hourly,
        now: noon,
      )!;
      for (var minute = 5; minute <= 60; minute += 5) {
        visit =
            PlaceVisitRules.advance(
              visit,
              distanceMeters: 40,
              every: AutoCheckIn.hourly,
              now: noon.add(Duration(minutes: minute)),
            ) ??
            visit;
      }

      expect(visit.checkInCount, 1, reason: 'the history counts it');
      expect(visit.hasVisited, isTrue);
      // …and the reward is still there to be collected.
      expect(visit.isClaimed, isFalse);
      expect(visit.claimedAt, isNull);
    });

    test('tapping after an hour nearby still claims it', () {
      final dwelled = benThanh.copyWith(checkInCount: 2, lastCheckInAt: noon);

      final claimed = PlaceVisitRules.visited(
        dwelled,
        now: noon.add(const Duration(hours: 1)),
      );

      expect(claimed.checkInCount, 3);
      expect(claimed.isClaimed, isTrue);
      expect(claimed.claimedAt, noon.add(const Duration(hours: 1)));
    });

    test('a second check-in does not move the claim', () {
      final first = PlaceVisitRules.visited(benThanh, now: noon);
      final second = PlaceVisitRules.visited(
        first,
        now: noon.add(const Duration(days: 3)),
      );

      // `claimedAt` is when the bonus was spent, not when the player was last
      // here — `lastCheckInAt` already answers that.
      expect(second.claimedAt, noon);
      expect(second.lastCheckInAt, noon.add(const Duration(days: 3)));
      expect(second.checkInCount, 2);
    });

    test('survives the trip to another phone', () {
      final claimed = PlaceVisitRules.visited(benThanh, now: noon);

      // The stay is a fact about the device and is dropped; whether the bonus
      // was spent is a fact about the player and travels.
      expect(claimed.withoutStay().claimedAt, noon);
      expect(claimed.withoutStay().stayStartedAt, isNull);
    });
  });
}
