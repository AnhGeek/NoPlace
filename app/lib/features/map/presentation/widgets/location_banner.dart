import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repository_providers.dart';
import '../../../../design_system/components/components.dart';
import '../../../../design_system/theme/np_typography.dart';
import '../../../../design_system/tokens/design_tokens.g.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../l10n/l10n.dart';

/// Says why the map is not opening, and offers the one thing that would fix it.
///
/// Deliberately not a dialog. A player who has refused the permission is
/// allowed to keep using the app — the map still has their old trail and their
/// own points on it — and being blocked by a modal they cannot dismiss is how
/// an app gets uninstalled. This sits over the map and can be ignored.
class LocationBanner extends ConsumerWidget {
  const LocationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(locationAvailabilityProvider).value;
    final l10n = context.l10n;

    final (title, body, action) = switch (availability) {
      LocationAvailability.serviceDisabled => (
        l10n.locationServiceOffTitle,
        l10n.locationServiceOffBody,
        l10n.locationActionTurnOn,
      ),
      LocationAvailability.denied => (
        l10n.locationDeniedTitle,
        l10n.locationDeniedBody,
        l10n.locationActionAllow,
      ),
      LocationAvailability.deniedForever => (
        l10n.locationDeniedForeverTitle,
        l10n.locationDeniedForeverBody,
        l10n.locationActionSettings,
      ),
      // Ready, still starting up, or not asked yet: nothing to say. The map is
      // the answer, not a banner about the map.
      _ => (null, null, null),
    };

    if (title == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(NpSpace.lg, NpSpace.md, NpSpace.lg, 0),
      child: NpCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: NpTypography.bodyStrong),
                  const SizedBox(height: NpSpace.xxs),
                  Text(
                    body!,
                    style: NpTypography.footnote.copyWith(
                      color: NpColors.contentMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NpSpace.md),
            NpPrimaryButton(
              label: action!,
              expand: false,
              compact: true,
              onPressed: () => _act(ref, availability!),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _act(WidgetRef ref, LocationAvailability problem) async {
    final location = ref.read(locationRepositoryProvider);

    // A plain refusal can simply be asked again — that is the whole difference
    // between `denied` and `deniedForever`, and it is why they are separate
    // states rather than one error.
    if (problem == LocationAvailability.denied) {
      await location.start();
      return;
    }

    await location.openSettingsFor(problem);
  }
}

/// Dismissed for this session only.
///
/// Deliberately not persisted. The cost of getting this wrong is asymmetric: a
/// player who dismisses it and later wonders why their walks have gaps is worse
/// off than one who sees the card again next launch, and the card disappears
/// for good the moment they say yes.
class _SleepBannerDismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

final _sleepBannerDismissedProvider =
    NotifierProvider<_SleepBannerDismissed, bool>(_SleepBannerDismissed.new);

/// Warns that the phone is still allowed to freeze NoPlace in a pocket.
///
/// A different problem from [LocationBanner]'s, with a different remedy, which
/// is why it is a second card rather than another case in that switch: the
/// permission can be granted and the foreground service running, and the walk
/// still comes back in pieces because battery saving put the process to sleep.
///
/// Android-only in practice — the repository reports `false` everywhere else,
/// so this builds to nothing on iOS.
class BackgroundSleepBanner extends ConsumerWidget {
  const BackgroundSleepBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optimised = ref.watch(batteryOptimisedProvider).value ?? false;
    final dismissed = ref.watch(_sleepBannerDismissedProvider);
    // Nothing to say until location is actually working: one problem at a time,
    // and the OS setting is moot while no fixes are arriving anyway.
    final ready =
        ref.watch(locationAvailabilityProvider).value ==
        LocationAvailability.ready;

    if (!optimised || dismissed || !ready) return const SizedBox.shrink();

    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(NpSpace.lg, NpSpace.md, NpSpace.lg, 0),
      child: NpCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.backgroundSleepTitle,
                    style: NpTypography.bodyStrong,
                  ),
                  const SizedBox(height: NpSpace.xxs),
                  Text(
                    l10n.backgroundSleepBody,
                    style: NpTypography.footnote.copyWith(
                      color: NpColors.contentMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NpSpace.md),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NpPrimaryButton(
                  label: l10n.backgroundSleepAction,
                  expand: false,
                  compact: true,
                  onPressed: () => unawaited(
                    ref
                        .read(locationRepositoryProvider)
                        .requestBatteryExemption(),
                  ),
                ),
                TextButton(
                  onPressed: ref
                      .read(_sleepBannerDismissedProvider.notifier)
                      .dismiss,
                  child: Text(
                    l10n.commonNotNow,
                    style: NpTypography.footnote.copyWith(
                      color: NpColors.contentMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
