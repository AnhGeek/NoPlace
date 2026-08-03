import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repository_providers.dart';
import '../../../../design_system/components/components.dart';
import '../../../../design_system/theme/np_typography.dart';
import '../../../../design_system/tokens/design_tokens.g.dart';
import '../../../../l10n/l10n.dart';

/// Asks, once, to be allowed to keep recording with the screen off.
///
/// This is a question and not a silent system call because the honest version
/// of it has two halves, and only one of them is in the OS dialog. The OS asks
/// "let this app ignore battery optimisation?", which tells the player nothing
/// about what they get; this says what the permission is *for* — the walk they
/// are about to take — and what it costs: a notification for as long as it
/// records, and nothing at all once NoPlace is closed.
///
/// Shown at most once per install (see
/// `PreferencesRepository.watchBackgroundPromptSeen`). Saying no is a complete
/// answer: [BackgroundSleepBanner] stays on the map for whenever they change
/// their mind, and the app records normally while it is on screen either way.
class BackgroundPermissionSheet extends ConsumerWidget {
  const BackgroundPermissionSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return NpSheetSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.backgroundAskTitle, style: NpTypography.title),
          const SizedBox(height: NpSpace.sm),
          Text(
            l10n.backgroundAskBody,
            style: NpTypography.body.copyWith(color: NpColors.contentMuted),
          ),
          const SizedBox(height: NpSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                size: NpSize.iconSm,
                color: NpColors.contentMuted,
              ),
              const SizedBox(width: NpSpace.sm),
              Expanded(
                child: Text(
                  l10n.backgroundAskNote,
                  style: NpTypography.footnote.copyWith(
                    color: NpColors.contentMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NpSpace.lg),
          NpPrimaryButton(
            label: l10n.backgroundAskAction,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: NpSpace.sm),
          NpGhostButton(
            label: l10n.commonNotNow,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

/// Puts the question, and acts on the answer.
///
/// Records that it was asked either way — a "not now" that comes back tomorrow
/// is the same nag the persistence exists to prevent — and only then opens the
/// system prompt, so a player who dismisses the sheet with the back gesture is
/// treated as having said no rather than being asked again next launch.
Future<void> showBackgroundPermissionSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final accepted = await showNpModalSheet<bool>(
    context: context,
    builder: (context) => const BackgroundPermissionSheet(),
  );

  await ref.read(preferencesRepositoryProvider).markBackgroundPromptSeen();
  if (accepted ?? false) {
    await ref.read(locationRepositoryProvider).requestBatteryExemption();
  }
}
