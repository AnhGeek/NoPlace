import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/local/region_catalogue.dart';
import '../../../../data/local/region_pack_store.dart';
import '../../../../data/repository_providers.dart';
import '../../../../design_system/components/components.dart';
import '../../../../design_system/theme/np_typography.dart';
import '../../../../design_system/tokens/design_tokens.g.dart';
import '../../../../l10n/l10n.dart';

/// Says that the player has crossed into a new region, and lets them choose
/// which region's map to walk with.
///
/// Crossing a border is a moment, not a silent swap — see decision 3 of
/// [NP-1](../../../../../docs/tickets/NP-1-region-packs-on-device.md). Two
/// things happen at once and the player is entitled to know about both: the
/// streets under them change, and so does the fog, because the trail is scoped
/// per region and each city keeps its own.
///
/// The picker is there because the claims are rectangles and the ground is not.
/// Somebody walking the river between Ho Chi Minh City and Đồng Nai is inside
/// one box and looking at the other, and both packs hold the tiles either way —
/// so the honest answer to "which city am I in" is to let them say.
class RegionArrivalSheet extends ConsumerStatefulWidget {
  const RegionArrivalSheet({required this.arrived, super.key});

  /// The region the ground resolved to. Where the picker starts.
  final RegionPackSource arrived;

  @override
  ConsumerState<RegionArrivalSheet> createState() => _RegionArrivalSheetState();
}

class _RegionArrivalSheetState extends ConsumerState<RegionArrivalSheet> {
  late RegionPackSource _selected = widget.arrived;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return NpSheetSurface(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.regionArrivedTitle(widget.arrived.name),
              style: NpTypography.title,
            ),
            const SizedBox(height: NpSpace.sm),
            Text(
              l10n.regionArrivedBody,
              style: NpTypography.body.copyWith(color: NpColors.contentMuted),
            ),
            const SizedBox(height: NpSpace.lg),
            Text(l10n.regionPickerLabel, style: NpTypography.label),
            const SizedBox(height: NpSpace.sm),
            for (final region in RegionCatalogue.all) ...[
              _RegionRow(
                region: region,
                selected: region.regionId == _selected.regionId,
                // A region with no pack on this phone would select to an empty
                // map, which looks exactly like the bug this sheet exists
                // downstream of. Say it is not here instead.
                onTap: region.bundledAsset == null
                    ? null
                    : () => setState(() => _selected = region),
              ),
              const SizedBox(height: NpSpace.sm),
            ],
            const SizedBox(height: NpSpace.md),
            NpPrimaryButton(
              label: l10n.regionArrivedAction,
              onPressed: () {
                ref.read(regionPackSourceProvider.notifier).select(_selected);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionRow extends StatelessWidget {
  const _RegionRow({
    required this.region,
    required this.selected,
    required this.onTap,
  });

  final RegionPackSource region;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final available = region.bundledAsset != null;

    return NpListRow(
      mark: NpRowMark(
        background: selected
            ? NpColors.statusSuccessMuted
            : NpColors.statusLocked,
        foreground: selected ? NpColors.contentOnStatus : NpColors.contentMuted,
        icon: selected ? Icons.check_rounded : Icons.map_outlined,
      ),
      title: region.name,
      subtitle: available
          ? l10n.regionPackOnDevice
          : l10n.regionPackNotDownloaded,
      dimmed: !available,
      onTap: onTap,
    );
  }
}

/// Announces [arrived] and applies whatever the player picks.
Future<void> showRegionArrivalSheet({
  required BuildContext context,
  required RegionPackSource arrived,
}) {
  return showNpModalSheet<void>(
    context: context,
    builder: (context) => RegionArrivalSheet(arrived: arrived),
  );
}
