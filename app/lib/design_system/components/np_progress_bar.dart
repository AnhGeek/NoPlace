import 'package:flutter/widgets.dart';

import '../theme/np_typography.dart';
import '../tokens/design_tokens.g.dart';

/// A 6dp track with a rounded fill. Used for district charting and any other
/// "how far along am I" number.
class NpProgressBar extends StatelessWidget {
  const NpProgressBar({
    required this.value,
    this.color = NpColors.accentDefault,
    this.animate = true,
    super.key,
  }) : assert(value >= 0 && value <= 1, 'value must be a 0..1 fraction');

  /// 0..1.
  final double value;
  final Color color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(NpSize.progressBar / 2),
      child: SizedBox(
        height: NpSize.progressBar,
        child: ColoredBox(
          color: NpColors.chartTrack,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth * value;
                final bar = DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(NpSize.progressBar / 2),
                  ),
                  child: const SizedBox.expand(),
                );
                return animate
                    ? AnimatedContainer(
                        duration: NpDuration.slow,
                        curve: NpEasing.standard,
                        width: width,
                        child: bar,
                      )
                    : SizedBox(width: width, child: bar);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled progress row: name on the left, percentage on the right, bar
/// underneath.
class NpProgressRow extends StatelessWidget {
  const NpProgressRow({
    required this.label,
    required this.trailing,
    required this.value,
    this.color = NpColors.accentDefault,
    this.dimmed = false,
    super.key,
  });

  final String label;
  final String trailing;
  final double value;
  final Color color;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: NpTypography.footnoteStrong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: NpSpace.xs),
            Text(trailing, style: NpTypography.footnote),
          ],
        ),
        const SizedBox(height: NpSpace.xxs),
        NpProgressBar(value: value, color: color),
      ],
    );

    return dimmed ? Opacity(opacity: NpOpacity.locked, child: row) : row;
  }
}
