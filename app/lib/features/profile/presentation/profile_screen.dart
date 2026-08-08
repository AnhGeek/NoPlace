import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/shell/home_shell.dart';
import '../../../core/formatting/unit_formatter.dart';
import '../../../data/local/region_catalogue.dart';
import '../../../data/local/region_pack_store.dart';
import '../../../data/repository_providers.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/theme/np_typography.dart';
import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../domain/entities/explorer_profile.dart';
import '../../../l10n/l10n.dart';

/// Who the player has become. Everything here is a consequence of walking, so
/// the numbers are the reward — no vanity fields, no editable bio.
///
/// And everything here is *theirs*: the name and the photo are on this phone,
/// the kilometres come from the trail on it, the districts come from the
/// boundaries of the map they are walking. Nothing is seeded and nothing is
/// fetched, which is why the ranking card says it has nothing to say.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// How many districts the card lists before it stops and counts the rest.
  /// A region is a couple of hundred wards; the profile is not the place to
  /// scroll them.
  static const int _districtsShown = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(explorerProfileProvider);
    final format = UnitFormatter.of(l10n);

    return SafeArea(
      bottom: false,
      child: ListView(
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
          _Identity(profile: profile),
          const SizedBox(height: NpSpace.md),
          Text(
            format.squareKilometers(profile.chartedSquareMeters),
            style: NpTypography.statHero,
            textAlign: TextAlign.center,
          ),
          Text(
            l10n.profileChartedCaption(profile.regionName),
            style: NpTypography.bodyLarge.copyWith(
              color: NpColors.contentSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NpSpace.lg),
          _StatRow(profile: profile, format: format),
          const SizedBox(height: NpSpace.lg),
          Text(
            l10n.profileMapsTitle,
            style: NpTypography.footnote.copyWith(color: NpColors.contentMuted),
          ),
          const SizedBox(height: NpSpace.xs),
          _MapChips(current: profile.regionId),
          const SizedBox(height: NpSpace.md),
          _DistrictProgressCard(profile: profile, format: format),
          const SizedBox(height: NpSpace.md),
          const _RankingCard(),
        ],
      ),
    );
  }
}

/// The avatar, the name and the level line — the three things the player owns
/// rather than earns.
class _Identity extends ConsumerWidget {
  const _Identity({required this.profile});

  final ExplorerProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final path = profile.avatarPath;
    // Read from disk, not from the bundle: this is a file the player chose. A
    // path that no longer resolves — a restore onto another phone, storage
    // cleared — falls back to the placeholder rather than an error box.
    final image = (path != null && File(path).existsSync())
        ? FileImage(File(path))
        : null;

    return Column(
      children: [
        Center(
          child: Semantics(
            button: true,
            label: l10n.profilePhotoChoose,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _editPhoto(context, ref),
              child: NpAvatar(imageProvider: image),
            ),
          ),
        ),
        const SizedBox(height: NpSpace.sm),
        InkWell(
          onTap: () => _editName(context, ref),
          borderRadius: BorderRadius.circular(NpRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NpSpace.sm,
              vertical: NpSpace.xxs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    profile.displayName.isEmpty
                        ? l10n.profileNamePlaceholder
                        : profile.displayName,
                    style: NpTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: NpSpace.xs),
                const Icon(
                  Icons.edit_outlined,
                  size: NpSize.iconSm,
                  color: NpColors.contentMuted,
                ),
              ],
            ),
          ),
        ),
        Text(
          l10n.profileLevelLine(profile.level, profile.xp),
          style: NpTypography.footnote,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: profile.displayName);

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileNameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(helperText: l10n.profileNameHint),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonNotNow),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.profileNameSave),
          ),
        ],
      ),
    );

    controller.dispose();
    if (name == null) return;
    await ref.read(preferencesRepositoryProvider).setDisplayName(name);
  }

  /// One sheet with both answers, because "remove" is only ever wanted by
  /// somebody who already has a picture — and offering it to everybody else
  /// would be a dead row.
  Future<void> _editPhoto(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final store = ref.read(avatarStoreProvider);
    if (!store.isSupported) return;

    final hasPhoto = profile.avatarPath != null;
    if (!hasPhoto) {
      await store.pick();
      return;
    }

    final removed = await showNpModalSheet<bool>(
      context: context,
      builder: (context) => NpSheetSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NpListRow(
              mark: const NpRowMark(
                background: NpColors.backgroundPanelRaised,
                foreground: NpColors.contentSecondary,
                icon: Icons.photo_outlined,
              ),
              title: l10n.profilePhotoChoose,
              onTap: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: NpSpace.sm),
            NpListRow(
              mark: const NpRowMark(
                background: NpColors.backgroundPanelRaised,
                foreground: NpColors.contentSecondary,
                icon: Icons.delete_outline_rounded,
              ),
              title: l10n.profilePhotoRemove,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );

    if (removed == null) return;
    await (removed ? store.clear() : store.pick());
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.profile, required this.format});

  final ExplorerProfile profile;
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
              value: format.distance(profile.walk.distanceTodayMeters),
              caption: l10n.profileStatDistanceToday,
            ),
          ),
          const SizedBox(width: NpSpace.sm),
          Expanded(
            child: NpStatTile(
              icon: Icons.location_on_rounded,
              iconBackground: NpColors.statusSuccessMuted,
              value: format.integer(profile.checkInPlaces),
              caption: l10n.profileStatCheckIns,
            ),
          ),
          const SizedBox(width: NpSpace.sm),
          Expanded(
            child: NpStatTile(
              icon: Icons.local_fire_department_rounded,
              iconBackground: NpColors.statusWarning,
              value: l10n.commonDays(profile.walk.streakDays),
              caption: l10n.profileStatStreak,
            ),
          ),
        ],
      ),
    );
  }
}

/// The maps on this phone, and which one the fog is currently being kept for.
///
/// Tapping one switches the map — the same call the arrival sheet makes when
/// the player crosses a border and picks the other side. A region with no pack
/// on the device is shown and not selectable: it is a map that exists, which is
/// worth knowing, and selecting it would open a blank city.
class _MapChips extends ConsumerWidget {
  const _MapChips({required this.current});

  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: RegionCatalogue.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: NpSpace.xs),
        itemBuilder: (context, index) {
          final region = RegionCatalogue.all[index];
          final selected = region.regionId == current;
          final available = region.bundledAsset != null;

          return NpChip(
            label: region.name,
            icon: selected ? Icons.location_on_rounded : null,
            selected: selected,
            dimmed: !available,
            onTap: available && !selected
                ? () => _select(ref, region)
                : null,
          );
        },
      ),
    );
  }

  void _select(WidgetRef ref, RegionPackSource region) =>
      ref.read(regionPackSourceProvider.notifier).select(region);
}

/// How much of each district the player has uncovered, most walked first.
class _DistrictProgressCard extends StatelessWidget {
  const _DistrictProgressCard({required this.profile, required this.format});

  final ExplorerProfile profile;
  final UnitFormatter format;

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
    final shown = profile.districts.take(ProfileScreen._districtsShown).toList();
    final remaining = profile.districts.length - shown.length;

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
                  l10n.profileDistrictProgressTitle(profile.regionName),
                  style: NpTypography.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (profile.hasDistrictData)
                Text(
                  l10n.logsDistrictCount(
                    profile.districtsCharted,
                    profile.districtsKnown,
                  ),
                  style: NpTypography.footnote,
                ),
            ],
          ),
          if (!profile.hasDistrictData || shown.isEmpty) ...[
            const SizedBox(height: NpSpace.sm),
            Text(
              profile.hasDistrictData
                  ? l10n.profileDistrictsEmpty
                  : l10n.profileDistrictsUnavailable,
              style: NpTypography.caption,
            ),
          ],
          for (var i = 0; i < shown.length; i++) ...[
            const SizedBox(height: NpSpace.md),
            NpProgressRow(
              label: shown[i].name,
              trailing: l10n.profileChartedShare(
                (shown[i].chartedFraction * 100).round(),
              ),
              value: shown[i].chartedFraction,
              color: _series[i % _series.length],
            ),
          ],
          if (remaining > 0) ...[
            const SizedBox(height: NpSpace.sm),
            Text(
              l10n.profileDistrictsMore(remaining),
              style: NpTypography.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// The leaderboard, honestly.
///
/// NoPlace keeps every walk on the phone that walked it — there is no account,
/// no upload and so nobody to be ranked against. The card stays because the
/// feature is coming; the numbers do not, because inventing a position out of
/// seeded data is the one thing a profile screen must never do.
class _RankingCard extends StatelessWidget {
  const _RankingCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return NpCard(
      child: Opacity(
        opacity: NpOpacity.locked,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(NpSpace.xs),
              decoration: BoxDecoration(
                color: NpColors.statusLocked,
                borderRadius: BorderRadius.circular(NpRadius.md),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: NpSize.iconXl,
                color: NpColors.contentMuted,
              ),
            ),
            const SizedBox(width: NpSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.profileRankingTitle, style: NpTypography.label),
                  Text(
                    l10n.profileRankingUnavailable,
                    style: NpTypography.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
