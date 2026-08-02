import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/shell/home_shell.dart';
import '../../../core/formatting/unit_formatter.dart';
import '../../../core/ui/np_async_view.dart';
import '../../../data/repository_providers.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/theme/np_typography.dart';
import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../domain/entities/district.dart';
import '../../../domain/entities/player.dart';
import '../../../l10n/l10n.dart';

/// Who the player has become. Everything here is a consequence of walking, so
/// the numbers are the reward — no vanity fields, no editable bio.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final player = ref.watch(playerProvider);
    final city = ref.watch(currentCityProvider).value;
    final districts = ref.watch(districtsProvider).value ?? const <District>[];

    return SafeArea(
      bottom: false,
      child: NpAsyncView<Player>(
        value: player,
        data: (player) {
          final format = UnitFormatter.of(l10n);

          return ListView(
            padding: EdgeInsets.fromLTRB(
              NpSpace.lg,
              0,
              NpSpace.lg,
              HomeShell.bottomInsetFor(context),
            ),
            children: [
              Row(
                children: [
                  Expanded(child: NpScreenHeader(title: l10n.profileTitle)),
                  IconButton(
                    onPressed: () => context.pushNamed(AppRoute.settingsName),
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: l10n.settingsTitle,
                  ),
                ],
              ),
              const SizedBox(height: NpSpace.xs),
              const Center(child: NpAvatar()),
              const SizedBox(height: NpSpace.sm),
              Text(
                player.displayName,
                style: NpTypography.headline,
                textAlign: TextAlign.center,
              ),
              Text(
                l10n.profileLevelLine(player.level, player.xp),
                style: NpTypography.footnote,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: NpSpace.md),
              Text(
                l10n.profileChartedShare(
                  (player.chartedFraction * 100).round(),
                ),
                style: NpTypography.statHero,
                textAlign: TextAlign.center,
              ),
              Text(
                l10n.profileChartedCaption,
                style: NpTypography.bodyLarge.copyWith(
                  color: NpColors.contentSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: NpSpace.lg),
              _StatRow(player: player, format: format),
              const SizedBox(height: NpSpace.lg),
              _CityChips(currentCityName: city?.name ?? ''),
              const SizedBox(height: NpSpace.md),
              _CityProgressCard(
                cityName: city?.name ?? '',
                districtCount: city?.districtCount ?? districts.length,
                districts: districts,
              ),
              const SizedBox(height: NpSpace.md),
              _RankingCard(player: player),
            ],
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.player, required this.format});

  final Player player;
  final UnitFormatter format;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: NpStatTile(
              icon: Icons.directions_walk_rounded,
              iconBackground: NpColors.statusInfo,
              value: format.distance(player.distanceTodayMeters),
              caption: l10n.profileStatDistanceToday,
            ),
          ),
          const SizedBox(width: NpSpace.sm),
          Expanded(
            child: NpStatTile(
              icon: Icons.location_on_rounded,
              iconBackground: NpColors.statusSuccessMuted,
              value: format.integer(player.checkInPlaces),
              caption: l10n.profileStatCheckIns,
            ),
          ),
          const SizedBox(width: NpSpace.sm),
          Expanded(
            child: NpStatTile(
              icon: Icons.local_fire_department_rounded,
              iconBackground: NpColors.statusWarning,
              value: l10n.commonDays(player.streakDays),
              caption: l10n.profileStatStreak,
            ),
          ),
        ],
      ),
    );
  }
}

class _CityChips extends StatelessWidget {
  const _CityChips({required this.currentCityName});

  final String currentCityName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          NpChip(
            label: l10n.profileCityCurrent(currentCityName),
            icon: Icons.location_on_rounded,
            selected: true,
          ),
          const SizedBox(width: NpSpace.xs),
          const NpChip(label: 'Hà Nội'),
          const SizedBox(width: NpSpace.xs),
          const NpChip(label: 'Đà Nẵng'),
          const SizedBox(width: NpSpace.xs),
          NpChip(label: l10n.profileAddCity),
        ],
      ),
    );
  }
}

class _CityProgressCard extends StatelessWidget {
  const _CityProgressCard({
    required this.cityName,
    required this.districtCount,
    required this.districts,
  });

  final String cityName;
  final int districtCount;
  final List<District> districts;

  /// Series colours cycle so neighbouring bars stay distinguishable without
  /// assigning meaning to the colour itself.
  static const List<Color> _series = [
    NpColors.chartSeries1,
    NpColors.chartSeries2,
    NpColors.chartSeries3,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final charted = districts.where((d) => d.isDiscovered).length;

    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  l10n.profileCityProgressTitle(cityName),
                  style: NpTypography.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                l10n.logsDistrictCount(charted, districtCount),
                style: NpTypography.footnote,
              ),
            ],
          ),
          const SizedBox(height: NpSpace.md),
          for (var i = 0; i < districts.length; i++) ...[
            if (i > 0) const SizedBox(height: NpSpace.md),
            NpProgressRow(
              label: districts[i].name.isEmpty
                  ? l10n.commonHidden
                  : districts[i].name,
              trailing: districts[i].name.isEmpty
                  ? l10n.commonLocked
                  : l10n.profileChartedShare(
                      (districts[i].chartedFraction * 100).round(),
                    ),
              value: districts[i].chartedFraction,
              color: _series[i % _series.length],
              dimmed: districts[i].name.isEmpty,
            ),
          ],
        ],
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return NpCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(NpSpace.xs),
            decoration: BoxDecoration(
              color: NpColors.statusRare,
              borderRadius: BorderRadius.circular(NpRadius.md),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: NpSize.iconXl,
              color: NpColors.contentOnStatus,
            ),
          ),
          const SizedBox(width: NpSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.profileRankingTitle, style: NpTypography.label),
                if (player.isRanked)
                  Text(
                    l10n.profileRankingSubtitle(
                      player.cityRank,
                      player.cityExplorers,
                    ),
                    style: NpTypography.caption,
                  ),
              ],
            ),
          ),
          if (player.rankTrendPercent > 0)
            NpPill(label: l10n.profileRankingTrend(player.rankTrendPercent)),
        ],
      ),
    );
  }
}
