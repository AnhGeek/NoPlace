import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/home_shell.dart';
import '../../../core/formatting/unit_formatter.dart';
import '../../../data/repository_providers.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/theme/np_typography.dart';
import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../domain/entities/fog_settings.dart';
import '../../../l10n/l10n.dart';

/// Tuning the fog, with the fog visible while you tune it.
///
/// The preview is the point. These two numbers cannot be chosen from their
/// names — "180 metres" means nothing until you see how much of a city block it
/// opens — so the panel shows a live clearing that resizes as you drag, over
/// the same dark ground the map uses.
class FogSettingsScreen extends ConsumerWidget {
  const FogSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings =
        ref.watch(fogSettingsProvider).value ?? const FogSettings();
    final format = UnitFormatter.of(l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsFogTitle)),
      body: ListView(
        // Same shell, same navigation bar over the body: the last control
        // needs the inset or it sits under it.
        padding: EdgeInsets.fromLTRB(
          NpSpace.lg,
          NpSpace.lg,
          NpSpace.lg,
          HomeShell.bottomInsetFor(context),
        ),
        children: [
          _Preview(settings: settings),
          const SizedBox(height: NpSpace.xl),

          _SettingHeader(
            title: l10n.settingsFogClearingRadius,
            value: format.distance(settings.clearingRadiusMeters),
            detail: l10n.settingsFogClearingRadiusDetail,
          ),
          Slider(
            value: settings.clearingRadiusMeters,
            min: FogSettings.minClearingRadius,
            max: FogSettings.maxClearingRadius,
            divisions:
                ((FogSettings.maxClearingRadius -
                            FogSettings.minClearingRadius) /
                        10)
                    .round(),
            label: format.distance(settings.clearingRadiusMeters),
            activeColor: NpColors.accentDefault,
            onChanged: (value) =>
                _save(ref, settings.copyWith(clearingRadiusMeters: value)),
          ),

          const SizedBox(height: NpSpace.lg),
          _SettingHeader(
            title: l10n.settingsFogPrecision,
            value: format.distance(settings.recordingPrecisionMeters),
            detail: l10n.settingsFogPrecisionDetail,
          ),
          const SizedBox(height: NpSpace.xs),
          Wrap(
            spacing: NpSpace.xs,
            children: [
              for (final step in FogSettings.precisionSteps)
                NpChip(
                  label: format.distance(step),
                  selected: settings.recordingPrecisionMeters == step,
                  onTap: () => _save(
                    ref,
                    settings.copyWith(recordingPrecisionMeters: step),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _save(WidgetRef ref, FogSettings settings) {
    unawaited(ref.read(preferencesRepositoryProvider).setFogSettings(settings));
  }
}

class _SettingHeader extends StatelessWidget {
  const _SettingHeader({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: NpTypography.label)),
            Text(
              value,
              style: NpTypography.label.copyWith(color: NpColors.accentDefault),
            ),
          ],
        ),
        Text(detail, style: NpTypography.caption),
      ],
    );
  }
}

/// A scale drawing of the current settings.
///
/// Not a map: a fixed 600 m-wide window on the same dark ground, with a walked
/// line through it. Using the real map here would mean the preview moved when
/// the player did, which is the opposite of what a settings preview is for.
class _Preview extends StatelessWidget {
  const _Preview({required this.settings});

  final FogSettings settings;

  /// How much ground the preview window shows, edge to edge.
  static const double _windowMeters = 600;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(NpRadius.lg),
      child: SizedBox(
        height: 220,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = constraints.maxWidth / _windowMeters;
            final centre = Offset(
              constraints.maxWidth / 2,
              constraints.maxHeight / 2,
            );

            // A short walk across the window, sampled at the chosen precision,
            // so the recording setting is visible too: coarse precision leaves
            // a chain of discs, fine precision a smooth corridor.
            const walkMeters = _windowMeters * 0.5;
            final step = settings.recordingPrecisionMeters.clamp(1.0, 40.0);
            final holes = <NpFogHole>[];
            for (var d = -walkMeters / 2; d <= walkMeters / 2; d += step) {
              holes.add(
                NpFogHole(
                  center: centre + Offset(d * scale, -d * scale * 0.35),
                  radius: settings.clearingRadiusMeters * scale,
                ),
              );
            }

            return ColoredBox(
              color: NpColors.backgroundExploredGround,
              child: Stack(
                children: [
                  Positioned.fill(child: NpFogOverlay(holes: holes)),
                  Positioned(
                    left: centre.dx - NpSize.playerDot / 2,
                    top: centre.dy - NpSize.playerDot / 2,
                    child: Container(
                      width: NpSize.playerDot,
                      height: NpSize.playerDot,
                      decoration: BoxDecoration(
                        color: NpColors.accentDefault,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: NpColors.borderOnMedia,
                          width: NpBorderWidth.heavy,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: NpSpace.xs,
                    bottom: NpSpace.xs,
                    child: Text(
                      '${_windowMeters.round()} m',
                      style: NpTypography.caption,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
