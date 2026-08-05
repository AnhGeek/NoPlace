import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/shell/home_shell.dart';
import '../../../core/formatting/unit_formatter.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../data/repository_providers.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/theme/np_typography.dart';
import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../domain/entities/map_layer_visibility.dart';
import '../../../domain/entities/map_point.dart';
import '../../../domain/rules/exploration_rules.dart';
import '../../../l10n/l10n.dart';

/// Settings. Short on purpose — the only thing worth choosing today is the
/// language.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(localeControllerProvider);
    final visibility =
        ref.watch(mapLayerVisibilityProvider).value ??
        const MapLayerVisibility();
    final radius =
        ref.watch(nearbyRadiusProvider).value ??
        ExplorationRules.defaultNearbyRadiusMeters;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        // Settings lives inside the shell, whose body extends behind the
        // navigation bar — without the inset the last card is half under it.
        padding: EdgeInsets.fromLTRB(
          NpSpace.lg,
          NpSpace.lg,
          NpSpace.lg,
          HomeShell.bottomInsetFor(context),
        ),
        children: [
          Text(
            l10n.settingsLanguage,
            style: NpTypography.footnote.copyWith(color: NpColors.contentMuted),
          ),
          const SizedBox(height: NpSpace.xs),
          NpCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _LanguageOption(
                  label: l10n.settingsLanguageSystem,
                  isSelected: selected == null,
                  onTap: () =>
                      ref.read(localeControllerProvider.notifier).select(null),
                ),
                for (final locale in L10nConfig.supported)
                  _LanguageOption(
                    label: L10nConfig.labelFor(locale),
                    isSelected: selected?.languageCode == locale.languageCode,
                    onTap: () => ref
                        .read(localeControllerProvider.notifier)
                        .select(locale),
                  ),
              ],
            ),
          ),
          const SizedBox(height: NpSpace.xl),
          Text(
            l10n.settingsMapLayers,
            style: NpTypography.footnote.copyWith(color: NpColors.contentMuted),
          ),
          const SizedBox(height: NpSpace.xs),
          NpCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _LayerToggle(
                  icon: Icons.place_outlined,
                  title: l10n.settingsShowSuggestedPoints,
                  subtitle: l10n.settingsShowSuggestedPointsDetail,
                  value: visibility.showSuggested,
                  onChanged: (value) =>
                      _setVisible(ref, MapPointKind.suggested, value),
                ),
                _LayerToggle(
                  icon: Icons.push_pin_outlined,
                  title: l10n.settingsHideUserPoints,
                  subtitle: l10n.settingsHideUserPointsDetail,
                  value: visibility.showUser,
                  onChanged: (value) =>
                      _setVisible(ref, MapPointKind.user, value),
                ),
                _LayerToggle(
                  icon: Icons.photo_camera_outlined,
                  title: l10n.settingsHidePicturePoints,
                  subtitle: l10n.settingsHidePicturePointsDetail,
                  value: visibility.showPictures,
                  onChanged: (value) =>
                      _setVisible(ref, MapPointKind.picture, value),
                ),
              ],
            ),
          ),
          const SizedBox(height: NpSpace.xl),
          Text(
            l10n.settingsNearby,
            style: NpTypography.footnote.copyWith(color: NpColors.contentMuted),
          ),
          const SizedBox(height: NpSpace.xs),
          NpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.settingsNearbyRadius,
                        style: NpTypography.label,
                      ),
                    ),
                    Text(
                      _radiusLabel(l10n, radius),
                      style: NpTypography.label.copyWith(
                        color: NpColors.accentDefault,
                      ),
                    ),
                  ],
                ),
                Text(
                  l10n.settingsNearbyRadiusDetail,
                  style: NpTypography.caption,
                ),
                const SizedBox(height: NpSpace.sm),

                // Chips rather than a slider: these are five choices, not a
                // continuum, and "2 km" is a decision a player can make from
                // the label alone.
                Wrap(
                  spacing: NpSpace.xs,
                  runSpacing: NpSpace.xs,
                  children: [
                    for (final step in ExplorationRules.nearbyRadiusSteps)
                      NpChip(
                        label: _radiusLabel(l10n, step),
                        selected: radius == step,
                        onTap: () => _setNearbyRadius(ref, step),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: NpSpace.md),
          NpCard(
            onTap: () => context.pushNamed(AppRoute.fogSettingsName),
            child: Row(
              children: [
                const Icon(
                  Icons.blur_on_rounded,
                  size: NpSize.iconXl,
                  color: NpColors.contentMuted,
                ),
                const SizedBox(width: NpSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.settingsFogTitle, style: NpTypography.label),
                      Text(
                        l10n.settingsFogSubtitle,
                        style: NpTypography.caption,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: NpColors.contentMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: NpSpace.md),
          NpCard(
            onTap: () => context.pushNamed(AppRoute.backupName),
            child: Row(
              children: [
                const Icon(
                  Icons.backup_outlined,
                  size: NpSize.iconXl,
                  color: NpColors.contentMuted,
                ),
                const SizedBox(width: NpSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.settingsBackupTitle, style: NpTypography.label),
                      Text(
                        l10n.settingsBackupSubtitle,
                        style: NpTypography.caption,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: NpColors.contentMuted,
                ),
              ],
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: NpSpace.xl),
            _DebugRow(
              icon: Icons.palette_outlined,
              label: l10n.settingsDesignGallery,
              onTap: () => context.pushNamed(AppRoute.galleryName),
            ),
            const SizedBox(height: NpSpace.xs),
            // The discovery screen only appears after a real first step into a
            // district, which is impossible to stage on a desk. This shortcut
            // is debug-only and never ships.
            _DebugRow(
              icon: Icons.auto_awesome_outlined,
              label: 'Preview: district discovered',
              onTap: () {
                final district = ref
                    .read(fakeWorldStoreProvider)
                    .previewNextDiscovery();
                if (district == null) return;
                context.pushNamed(AppRoute.discoveryName, extra: district);
              },
            ),
          ],
        ],
      ),
    );
  }

  /// "500 m", "2 km" — never "2.0 km", which reads like a measurement rather
  /// than a choice.
  String _radiusLabel(AppL10n l10n, double meters) {
    final format = UnitFormatter.of(l10n);
    if (meters < 1000) return format.distance(meters);
    return l10n.commonDistanceKilometers(format.kilometersCompact(meters));
  }

  void _setNearbyRadius(WidgetRef ref, double meters) {
    unawaited(
      ref.read(preferencesRepositoryProvider).setNearbyRadiusMeters(meters),
    );
  }

  void _setVisible(WidgetRef ref, MapPointKind kind, bool visible) {
    unawaited(
      ref
          .read(preferencesRepositoryProvider)
          .setMapLayerVisible(kind, visible: visible),
    );
  }
}

/// A row that turns one kind of map point on or off.
class _LayerToggle extends StatelessWidget {
  const _LayerToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: NpColors.contentMuted),
      activeThumbColor: NpColors.contentOnAccent,
      activeTrackColor: NpColors.accentDefault,
      title: Text(title, style: NpTypography.body),
      subtitle: Text(subtitle, style: NpTypography.caption),
    );
  }
}

/// A debug-only navigation row. Visually a card, deliberately plain: these are
/// developer tools, not product surface.
class _DebugRow extends StatelessWidget {
  const _DebugRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NpCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: NpSize.iconXl, color: NpColors.contentMuted),
          const SizedBox(width: NpSpace.md),
          Expanded(child: Text(label, style: NpTypography.label)),
          const Icon(Icons.chevron_right_rounded, color: NpColors.contentMuted),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(label, style: NpTypography.body),
      trailing: isSelected
          ? const Icon(
              Icons.check_rounded,
              color: NpColors.accentDefault,
              size: NpSize.iconLg,
            )
          : null,
    );
  }
}
