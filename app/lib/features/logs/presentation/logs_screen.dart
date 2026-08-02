import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/home_shell.dart';
import '../../../core/formatting/unit_formatter.dart';
import '../../../core/ui/np_async_view.dart';
import '../../../data/repository_providers.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/theme/np_typography.dart';
import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../domain/entities/log_entry.dart';
import '../../../l10n/l10n.dart';
import '../../quests/presentation/quest_tile.dart';

/// Which half of the log the player is looking at.
enum LogFilter { districts, quests }

final logFilterProvider = NotifierProvider<LogFilterController, LogFilter>(
  LogFilterController.new,
);

class LogFilterController extends Notifier<LogFilter> {
  @override
  LogFilter build() => LogFilter.districts;

  // ignore: use_setters_to_change_properties
  void select(LogFilter filter) => state = filter;
}

/// The player's history: what they uncovered, in the order it happened.
///
/// This screen is the receipt for the walking. It has to work when it is empty
/// on day one and when it is 400 rows long a year later, which is why it is a
/// lazy list with a fixed header rather than a scrolling column.
class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(logFilterProvider);
    final entries = ref.watch(logEntriesProvider);
    final districts = ref.watch(districtsProvider).value ?? const [];
    final charted = districts.where((d) => d.isDiscovered).length;
    final city = ref.watch(currentCityProvider).value;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NpSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NpScreenHeader(
              title: l10n.logsTitle,
              trailingText: l10n.logsDistrictCount(
                charted,
                city?.districtCount ?? districts.length,
              ),
            ),
            const SizedBox(height: NpSpace.xs),
            NpSegmentedControl<LogFilter>(
              selected: filter,
              onChanged: ref.read(logFilterProvider.notifier).select,
              segments: [
                NpSegment(
                  value: LogFilter.districts,
                  label: l10n.logsSegmentDistricts,
                ),
                NpSegment(
                  value: LogFilter.quests,
                  label: l10n.logsSegmentQuests,
                ),
              ],
            ),
            const SizedBox(height: NpSpace.md),
            Expanded(
              child: switch (filter) {
                LogFilter.districts => NpAsyncView<List<LogEntry>>(
                  value: entries,
                  data: (entries) => _LogList(entries: entries),
                ),
                LogFilter.quests => const _QuestLogList(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({required this.entries});

  final List<LogEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(NpSpace.xl),
          child: Text(
            context.l10n.logsEmpty,
            style: NpTypography.body.copyWith(color: NpColors.contentMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.only(bottom: HomeShell.bottomInsetFor(context)),
      itemCount: entries.length,
      separatorBuilder: (context, index) => const SizedBox(height: NpSpace.sm),
      itemBuilder: (context, index) => LogEntryTile(entry: entries[index]),
    );
  }
}

/// The quest half of the log reuses the quest rows, so a completed quest reads
/// the same in both places.
class _QuestLogList extends ConsumerWidget {
  const _QuestLogList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(questsProvider);

    return NpAsyncView(
      value: quests,
      data: (quests) => ListView.separated(
        padding: EdgeInsets.only(bottom: HomeShell.bottomInsetFor(context)),
        itemCount: quests.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: NpSpace.sm),
        itemBuilder: (context, index) => QuestTile(quest: quests[index]),
      ),
    );
  }
}

/// One log row. The `switch` is exhaustive over the sealed [LogEntry], so a new
/// kind of entry cannot be added without deciding how it looks.
class LogEntryTile extends StatelessWidget {
  const LogEntryTile({required this.entry, super.key});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = UnitFormatter.of(l10n);
    final xp = entry.xpAwarded;

    return switch (entry) {
      DistrictLogEntry(
        :final districtName,
        :final chartedFraction,
        :final at,
      ) =>
        NpListRow(
          mark: const NpRowMark.done(),
          title: districtName,
          subtitle: l10n.logsEntryDistrictCharted(
            format.weekday(at),
            (chartedFraction * 100).round(),
          ),
          trailing: xp == null ? null : NpXpLabel(l10n.commonXp(xp)),
        ),
      CheckInLogEntry(:final placeName, :final at) => NpListRow(
        mark: const NpRowMark.done(),
        title: placeName,
        subtitle: l10n.logsEntryCheckedInToday(format.timeOfDay(at)),
        trailing: xp == null ? null : NpXpLabel(l10n.commonXp(xp)),
      ),
      UnknownSiteLogEntry(:final distanceMeters) => NpListRow(
        mark: const NpRowMark.question(),
        title: l10n.logsUnknownSite,
        subtitle: l10n.logsEntryWithinQuestRadius(
          format.distance(distanceMeters),
        ),
        trailing: xp == null ? null : NpXpLabel(l10n.commonXp(xp)),
      ),
      LockedLogEntry() => NpListRow(
        mark: const NpRowMark.locked(),
        title: l10n.commonHidden,
        subtitle: l10n.logsEntryLocked,
        dimmed: true,
      ),
    };
  }
}
