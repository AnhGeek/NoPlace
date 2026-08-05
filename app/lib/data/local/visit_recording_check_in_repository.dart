import '../../domain/entities/check_in.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/rules/place_visit_rules.dart';

/// Wraps a [CheckInRepository] so that every accepted check-in is also written
/// into the player's own history of that place.
///
/// A decorator rather than a line in the check-in controller, because "checking
/// in is what makes a visit" is true of the check-in, not of the screen that
/// happened to trigger it. When the places API arrives and the inner repository
/// becomes an HTTP call, this stays exactly as it is.
///
/// Only the *inner* repository can refuse — out of range, unknown place. This
/// never records anything the rules did not already accept, because it only
/// runs after they have returned a result.
class VisitRecordingCheckInRepository implements CheckInRepository {
  const VisitRecordingCheckInRepository(this._inner, this._visits);

  final CheckInRepository _inner;
  final PlaceVisitRepository _visits;

  @override
  Future<CheckInResult> checkIn(String placeId) async {
    final result = await _inner.checkIn(placeId);
    await _visits.save(
      PlaceVisitRules.visited(_visits.of(placeId), now: DateTime.now()),
    );
    return result;
  }
}
