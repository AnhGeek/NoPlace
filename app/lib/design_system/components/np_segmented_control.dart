import 'package:flutter/material.dart';

import '../theme/np_typography.dart';
import '../tokens/design_tokens.g.dart';

/// Pill-shaped switch between two or three sibling lists.
///
/// Use it when the options show *the same kind of thing* filtered differently.
/// For switching between different screens, use navigation instead.
class NpSegmentedControl<T> extends StatelessWidget {
  const NpSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  }) : assert(segments.length >= 2, 'a segmented control needs 2+ options');

  final List<NpSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: NpColors.backgroundPanel,
        borderRadius: BorderRadius.circular(NpRadius.xxl),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: _Segment<T>(
                segment: segment,
                isSelected: segment.value == selected,
                onTap: () => onChanged(segment.value),
              ),
            ),
        ],
      ),
    );
  }
}

class NpSegment<T> {
  const NpSegment({required this.value, required this.label});

  final T value;
  final String label;
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.isSelected,
    required this.onTap,
  });

  final NpSegment<T> segment;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: NpDuration.fast,
          curve: NpEasing.standard,
          padding: const EdgeInsets.symmetric(vertical: NpSpace.xs),
          decoration: BoxDecoration(
            color: isSelected ? NpColors.accentDefault : Colors.transparent,
            borderRadius: BorderRadius.circular(NpRadius.xl),
          ),
          alignment: Alignment.center,
          child: Text(
            segment.label,
            style: NpTypography.footnote.copyWith(
              color: isSelected
                  ? NpColors.contentOnAccent
                  : NpColors.contentMuted,
              fontWeight: NpFontWeight.semibold,
            ),
          ),
        ),
      ),
    );
  }
}
