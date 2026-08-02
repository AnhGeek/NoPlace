import 'package:flutter/material.dart';

import '../tokens/design_tokens.g.dart';

/// The teardrop marker used on the map and, at a smaller size, inside cards
/// that refer to a place.
///
/// Drawn with a rotated rounded square so the tail points at the exact
/// coordinate; the icon is counter-rotated to stay upright.
class NpMapPin extends StatelessWidget {
  const NpMapPin({
    required this.icon,
    required this.color,
    this.size = NpSize.mapPin,
    super.key,
  });

  /// The compact variant used inline in lists and sheets.
  const NpMapPin.small({required this.icon, required this.color, super.key})
    : size = NpSize.mapPinSmall;

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.7853981633974483, // -45°, so the sharp corner points down.
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: NpColors.borderOnMedia,
            width: NpBorderWidth.thick,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(999),
            topRight: Radius.circular(999),
            bottomRight: Radius.circular(999),
            bottomLeft: Radius.circular(NpRadius.xs),
          ),
          boxShadow: const [NpShadows.marker],
        ),
        alignment: Alignment.center,
        child: Transform.rotate(
          angle: 0.7853981633974483,
          child: Icon(icon, size: size * 0.47, color: NpColors.contentOnAccent),
        ),
      ),
    );
  }
}

/// The player's own position: a solid dot with a slow expanding ring, so the
/// eye finds "me" before it finds anything else on the map.
class NpPlayerMarker extends StatefulWidget {
  const NpPlayerMarker({super.key});

  @override
  State<NpPlayerMarker> createState() => _NpPlayerMarkerState();
}

class _NpPlayerMarkerState extends State<NpPlayerMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NpDuration.pulse,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: NpSize.playerHalo,
      height: NpSize.playerHalo,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The expanding ring. Excluded from semantics: it says nothing a
          // screen reader user needs to hear.
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              return Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.6 + t * 0.75, child: child),
              );
            },
            child: Container(
              width: NpSize.playerHalo,
              height: NpSize.playerHalo,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: NpColors.accentGlow,
                  width: NpBorderWidth.hairline,
                ),
              ),
            ),
          ),
          Container(
            width: NpSize.playerDot,
            height: NpSize.playerDot,
            decoration: BoxDecoration(
              color: NpColors.accentDefault,
              shape: BoxShape.circle,
              border: Border.all(
                color: NpColors.borderOnMedia,
                width: NpBorderWidth.heavy,
              ),
              boxShadow: const [
                BoxShadow(
                  color: NpColors.accentGlow,
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
