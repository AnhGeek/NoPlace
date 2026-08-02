import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repository_providers.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/theme/np_typography.dart';
import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../domain/entities/district.dart';
import '../../../l10n/l10n.dart';

/// The payoff.
///
/// Full screen, no navigation bar, one button — for three seconds the app has
/// nothing else to say. The badge scales in on the emphasized curve so it lands
/// with a small overshoot instead of arriving flat.
class DistrictDiscoveredScreen extends ConsumerStatefulWidget {
  const DistrictDiscoveredScreen({required this.district, super.key});

  final District district;

  @override
  ConsumerState<DistrictDiscoveredScreen> createState() =>
      _DistrictDiscoveredScreenState();
}

class _DistrictDiscoveredScreenState
    extends ConsumerState<DistrictDiscoveredScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NpDuration.reveal,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final city = ref.watch(currentCityProvider).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Opaque base first, glow on top: this screen is a takeover, and letting
      // the screen underneath show through would undercut the moment.
      body: ColoredBox(
        color: NpColors.backgroundCanvas,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.15),
              radius: 0.9,
              colors: [Color(0x33F56B26), Color(0x0008080A)],
              stops: [0, 0.7],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: NpSpace.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _controller,
                        curve: NpEasing.emphasized,
                      ),
                      child: const _DiscoveryBadge(),
                    ),
                    const SizedBox(height: NpSpace.md),
                    Text(
                      l10n.discoveryKicker,
                      style: NpTypography.overline,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NpSpace.xs),
                    Text(
                      widget.district.name,
                      style: NpTypography.stat,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NpSpace.xxs),
                    Text(
                      l10n.discoveryMeta(
                        widget.district.index,
                        city?.districtCount ?? 0,
                        city?.name ?? '',
                      ),
                      style: NpTypography.body.copyWith(
                        color: NpColors.contentMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NpSpace.md),
                    NpPill(label: l10n.commonXp(_districtXp), large: true),
                    const SizedBox(height: NpSpace.xxl),
                    SizedBox(
                      width: 220,
                      child: NpPrimaryButton(
                        label: l10n.discoveryAction,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Kept in sync with the award in the check-in rules; it moves to the reward
  /// payload as soon as the server owns the numbers.
  static const int _districtXp = 100;
}

class _DiscoveryBadge extends StatelessWidget {
  const _DiscoveryBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: NpSize.discoveryBadge,
      height: NpSize.discoveryBadge,
      decoration: BoxDecoration(
        color: NpColors.accentSubtle,
        shape: BoxShape.circle,
        border: Border.all(
          color: NpColors.accentDefault,
          width: NpBorderWidth.thick,
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.map_outlined,
        size: NpSize.iconHero,
        color: NpColors.accentDefault,
      ),
    );
  }
}
