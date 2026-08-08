import 'package:flutter/material.dart';

import '../components/components.dart';
import '../theme/np_typography.dart';
import '../tokens/design_tokens.g.dart';

/// A live catalogue of the design system.
///
/// Debug-only, reachable from Settings. It exists so a component can be
/// reviewed on a real device without walking to a real place, and so a
/// regression in a shared widget is visible in one screen instead of five.
class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({super.key});

  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  int _segment = 0;
  int _chip = 0;
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design system')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          NpSpace.lg,
          NpSpace.lg,
          NpSpace.lg,
          NpSpace.huge,
        ),
        children: [
          const _Section('Colour'),
          const _Swatches(),
          const _Section('Type ramp'),
          const Text('Display 22 · screen titles', style: NpTypography.display),
          const Text('Headline 20', style: NpTypography.headline),
          const Text('Title 17', style: NpTypography.title),
          const Text('Label 15', style: NpTypography.label),
          const Text(
            'Body 14 — the default reading size',
            style: NpTypography.body,
          ),
          const Text('Footnote 13', style: NpTypography.footnote),
          const Text('Caption 12', style: NpTypography.caption),
          const Text('OVERLINE 12', style: NpTypography.overline),
          const _Section('Buttons'),
          NpPrimaryButton(label: 'Primary action', onPressed: () {}),
          const SizedBox(height: NpSpace.xs),
          const NpPrimaryButton(label: 'Disabled', onPressed: null),
          const SizedBox(height: NpSpace.xs),
          NpGhostButton(label: 'Ghost', onPressed: () {}),
          const SizedBox(height: NpSpace.xs),
          NpGhostButton(
            label: 'Ghost, with something to save',
            icon: Icons.save_rounded,
            emphasized: true,
            onPressed: () {},
          ),
          const _Section('Selection'),
          NpSegmentedControl<int>(
            selected: _segment,
            onChanged: (value) => setState(() => _segment = value),
            segments: const [
              NpSegment(value: 0, label: 'Districts'),
              NpSegment(value: 1, label: 'Quests'),
            ],
          ),
          const SizedBox(height: NpSpace.sm),
          Row(
            children: [
              NpChip(
                label: 'Selected',
                icon: Icons.location_on_rounded,
                selected: _chip == 0,
                onTap: () => setState(() => _chip = 0),
              ),
              const SizedBox(width: NpSpace.xs),
              NpChip(
                label: 'Idle',
                selected: _chip == 1,
                onTap: () => setState(() => _chip = 1),
              ),
            ],
          ),
          const SizedBox(height: NpSpace.sm),
          NpTopTabs<int>(
            selected: _tab,
            onChanged: (value) => setState(() => _tab = value),
            tabs: const [
              NpTopTab(value: 0, label: 'CITY'),
              NpTopTab(value: 1, label: 'NEARBY'),
            ],
          ),
          const _Section('Rows'),
          const NpListRow(
            mark: NpRowMark.done(),
            title: 'District 1',
            subtitle: 'First entered Tue · 38% charted',
            trailing: NpXpLabel('+100'),
          ),
          const SizedBox(height: NpSpace.sm),
          const NpListRow(
            mark: NpRowMark.question(),
            title: 'Unknown site',
            subtitle: '480 m away · within quest radius',
            trailing: NpXpLabel('+50'),
          ),
          const SizedBox(height: NpSpace.sm),
          const NpListRow(
            mark: NpRowMark.locked(),
            title: '???',
            subtitle: 'Locked · travel there to reveal',
            dimmed: true,
          ),
          const _Section('Progress'),
          const NpProgressRow(
            label: 'District 1',
            trailing: '62%',
            value: 0.62,
          ),
          const SizedBox(height: NpSpace.md),
          const NpProgressRow(
            label: 'District 3',
            trailing: '24%',
            value: 0.24,
            color: NpColors.chartSeries2,
          ),
          const _Section('Stats'),
          const IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: NpStatTile(
                    icon: Icons.directions_walk_rounded,
                    value: '4.2 km',
                    caption: 'Distance today',
                    iconBackground: NpColors.statusInfo,
                  ),
                ),
                SizedBox(width: NpSpace.sm),
                Expanded(
                  child: NpStatTile(
                    icon: Icons.location_on_rounded,
                    value: '27',
                    caption: 'Check-in places',
                    iconBackground: NpColors.statusSuccessMuted,
                  ),
                ),
                SizedBox(width: NpSpace.sm),
                Expanded(
                  child: NpStatTile(
                    icon: Icons.local_fire_department_rounded,
                    value: '6 days',
                    caption: 'Active streak',
                    iconBackground: NpColors.statusWarning,
                  ),
                ),
              ],
            ),
          ),
          const _Section('Map'),
          const SizedBox(
            height: 120,
            child: ColoredBox(
              color: NpColors.backgroundCanvas,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  NpMapPin(
                    icon: Icons.restaurant_rounded,
                    color: NpColors.categoryFood,
                  ),
                  NpMapPin(
                    icon: Icons.local_cafe_rounded,
                    color: NpColors.categoryCafe,
                  ),
                  NpMapPin(
                    icon: Icons.account_balance_rounded,
                    color: NpColors.categoryLandmark,
                  ),
                  NpPlayerMarker(),
                ],
              ),
            ),
          ),
          const _Section('Badges'),
          const Row(
            children: [
              NpPill(label: '+14%'),
              SizedBox(width: NpSpace.xs),
              NpPill(label: '+100 XP', color: NpColors.accentDefault),
              SizedBox(width: NpSpace.xs),
              NpPill(label: 'Rare', color: NpColors.statusRare),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: NpSpace.xl, bottom: NpSpace.xs),
      child: Text(title.toUpperCase(), style: NpTypography.overline),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches();

  static const Map<String, Color> _colors = {
    'accent': NpColors.accentDefault,
    'success': NpColors.statusSuccess,
    'info': NpColors.statusInfo,
    'warning': NpColors.statusWarning,
    'rare': NpColors.statusRare,
    'cafe': NpColors.categoryCafe,
    'landmark': NpColors.categoryLandmark,
    'panel': NpColors.backgroundPanel,
    'surface': NpColors.backgroundSurface,
    'canvas': NpColors.backgroundCanvas,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: NpSpace.xs,
      runSpacing: NpSpace.xs,
      children: [
        for (final entry in _colors.entries)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 40,
                decoration: BoxDecoration(
                  color: entry.value,
                  borderRadius: BorderRadius.circular(NpRadius.sm),
                  border: Border.all(color: NpColors.borderSubtle),
                ),
              ),
              const SizedBox(height: NpSpace.hair),
              Text(entry.key, style: NpTypography.caption),
            ],
          ),
      ],
    );
  }
}
