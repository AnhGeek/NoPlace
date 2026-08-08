import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/domain/rules/walk_rules.dart';

void main() {
  group('what counts as walking', () {
    test('an ordinary step does', () {
      expect(
        WalkRules.countsAsWalking(12, const Duration(seconds: 9)),
        isTrue,
      );
    });

    test('a quiet patch with the phone in a pocket still does', () {
      // The OS put the app to sleep; the player kept walking. Four hundred
      // metres in six minutes is a walk, and refusing it would quietly cost
      // people the distance they are proudest of.
      expect(
        WalkRules.countsAsWalking(400, const Duration(minutes: 6)),
        isTrue,
      );
    });

    test('a drive does not, however continuous the fixes', () {
      expect(
        WalkRules.countsAsWalking(2000, const Duration(minutes: 3)),
        isFalse,
      );
    });

    test('nor does a gap long enough to have been anything', () {
      expect(
        WalkRules.countsAsWalking(300, const Duration(hours: 2)),
        isFalse,
      );
    });
  });

  group('streaks', () {
    String day(int year, int month, int dayOfMonth) =>
        WalkRules.dayOf(DateTime(year, month, dayOfMonth));

    final now = DateTime(2026, 8, 8, 19, 30);

    test('nothing walked is no streak', () {
      expect(WalkRules.streakOf(const {}, now: now), 0);
    });

    test('counts back from today', () {
      final days = {
        day(2026, 8, 8),
        day(2026, 8, 7),
        day(2026, 8, 6),
      };
      expect(WalkRules.streakOf(days, now: now), 3);
    });

    test('today missing does not break it — the day is not over', () {
      final days = {day(2026, 8, 7), day(2026, 8, 6)};
      expect(WalkRules.streakOf(days, now: now), 2);
    });

    test('yesterday missing does', () {
      // A day that ended with nobody going out. Whatever came before it is
      // history, not a streak.
      final days = {day(2026, 8, 6), day(2026, 8, 5), day(2026, 8, 4)};
      expect(WalkRules.streakOf(days, now: now), 0);
    });

    test('runs across the end of a month', () {
      final days = {
        day(2026, 8, 1),
        day(2026, 7, 31),
        day(2026, 7, 30),
      };
      expect(
        WalkRules.streakOf(days, now: DateTime(2026, 8, 1, 8)),
        3,
      );
    });

    test('a day is the local one, not UTC', () {
      // Ten at night in Vietnam is already tomorrow in UTC. An evening walk
      // belongs to the evening it happened on.
      final evening = DateTime(2026, 8, 8, 22, 30);
      expect(WalkRules.dayOf(evening), '2026-08-08');
    });
  });
}
