import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repository_providers.dart';
import '../../../domain/entities/check_in.dart';

/// Drives the check-in button: idle → in flight → done or failed.
///
/// An [AsyncNotifier] rather than a bare `Future` in the widget, so the sheet
/// cannot fire two check-ins by double tap and the pending state survives a
/// rebuild.
class CheckInController extends AsyncNotifier<CheckInResult?> {
  @override
  Future<CheckInResult?> build() async => null;

  Future<CheckInResult?> checkIn(String placeId) async {
    if (state.isLoading) return null;

    state = const AsyncValue<CheckInResult?>.loading();
    final result = await AsyncValue.guard(
      () => ref.read(checkInRepositoryProvider).checkIn(placeId),
    );
    state = result;

    final value = result.value;
    if (value != null) {
      ref.read(lastCheckInResultProvider.notifier).record(value);
      // Claiming a place proves you stood at it, so it joins the trail even if
      // no position fix landed while the sheet was open.
      await ref
          .read(explorationTrailRepositoryProvider)
          .record(value.place.location);
    }
    return value;
  }
}

final checkInControllerProvider =
    AsyncNotifierProvider<CheckInController, CheckInResult?>(
      CheckInController.new,
    );
