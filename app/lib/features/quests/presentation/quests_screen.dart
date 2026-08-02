import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/home_shell.dart';
import '../../../core/ui/np_async_view.dart';
import '../../../data/repository_providers.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/theme/np_typography.dart';
import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../domain/entities/quest.dart';
import '../../../l10n/l10n.dart';
import 'quest_tile.dart';

/// What to do next, ranked. The weekly challenge sits on top because it is the
/// only goal that survives a bad day.
class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final quests = ref.watch(questsProvider);
    final challenge = ref.watch(weeklyChallengeProvider).value;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NpSpace.lg),
        child: NpAsyncView<List<Quest>>(
          value: quests,
          data: (quests) {
            final active = quests.where((quest) => !quest.isLocked).length;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: NpScreenHeader(
                    title: l10n.questsTitle,
                    trailingText: l10n.questsActiveCount(active),
                  ),
                ),
                if (challenge != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: NpSpace.xs),
                      child: _WeeklyChallengeCard(challenge: challenge),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: NpSpace.md,
                    bottom: HomeShell.bottomInsetFor(context),
                  ),
                  sliver: SliverList.separated(
                    itemCount: quests.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: NpSpace.sm),
                    itemBuilder: (context, index) =>
                        QuestTile(quest: quests[index]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WeeklyChallengeCard extends StatelessWidget {
  const _WeeklyChallengeCard({required this.challenge});

  final WeeklyChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return NpCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x2EF56B26), Color(0x1F316DCA)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.questsWeeklyChallenge,
                  style: NpTypography.label.copyWith(
                    fontWeight: NpFontWeight.bold,
                  ),
                ),
                Text(
                  l10n.questsWeeklyChallengeGoal(
                    challenge.target,
                    challenge.done,
                  ),
                  style: NpTypography.caption,
                ),
                const SizedBox(height: NpSpace.xs),
                NpProgressBar(value: challenge.progress),
              ],
            ),
          ),
          const SizedBox(width: NpSpace.md),
          Text(
            l10n.commonXp(challenge.xpReward),
            style: NpTypography.title.copyWith(color: NpColors.accentDefault),
          ),
        ],
      ),
    );
  }
}
