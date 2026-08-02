import 'package:flutter/widgets.dart';

import '../tokens/design_tokens.g.dart';

/// A hole punched in the fog: everywhere the player has already uncovered.
class NpFogHole {
  const NpFogHole({required this.center, required this.radius});

  /// Centre in the overlay's local coordinate space (logical pixels).
  final Offset center;

  /// Radius of the cleared disc, in logical pixels. The edge is hard: what is
  /// uncovered is uncovered.
  final double radius;
}

/// The fog of war.
///
/// This is the mechanic the whole product hangs on: the city is dark until the
/// player physically goes there.
///
/// The clearing is a **hard-edged union of discs**, not a soft vignette. Two
/// reasons, both learned the hard way:
///
/// * A gradient makes the boundary a matter of opinion. The player wants to see
///   exactly how far they got, and a fade turns "I walked to that corner" into
///   "something happened around there".
/// * Overlapping soft discs sum their alpha, so a re-walked street came out
///   brighter than a street walked once — the map rewarded pacing back and
///   forth. A hard edge composites idempotently: walking somewhere twice looks
///   identical to walking it once, which is the truth.
class NpFogOverlay extends StatelessWidget {
  const NpFogOverlay({required this.holes, super.key});

  final List<NpFogHole> holes;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(size: Size.infinite, painter: _FogPainter(holes)),
      ),
    );
  }
}

class _FogPainter extends CustomPainter {
  const _FogPainter(this.holes);

  final List<NpFogHole> holes;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    // saveLayer so the dstOut blend below erases the fog rather than the whole
    // scene underneath it.
    canvas
      ..saveLayer(bounds, Paint())
      ..drawRect(bounds, Paint()..color = NpColors.backgroundFog);

    // One opaque paint for every disc: no shader, no per-hole allocation, and
    // an exactly idempotent union.
    final eraser = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = const Color(0xFF000000)
      ..isAntiAlias = true;

    for (final hole in holes) {
      canvas.drawCircle(hole.center, hole.radius, eraser);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_FogPainter oldDelegate) =>
      !identical(oldDelegate.holes, holes);
}
