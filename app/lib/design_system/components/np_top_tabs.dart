import 'package:flutter/material.dart';

import '../theme/np_typography.dart';
import '../tokens/design_tokens.g.dart';

/// Full-width underlined tabs, used over the map to switch scope.
class NpTopTabs<T> extends StatelessWidget {
  const NpTopTabs({
    required this.tabs,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<NpTopTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tab in tabs)
          Expanded(
            child: _Tab<T>(
              tab: tab,
              isSelected: tab.value == selected,
              onTap: () => onChanged(tab.value),
            ),
          ),
      ],
    );
  }
}

class NpTopTab<T> {
  const NpTopTab({required this.value, required this.label});

  final T value;
  final String label;
}

class _Tab<T> extends StatelessWidget {
  const _Tab({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final NpTopTab<T> tab;
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
          padding: const EdgeInsets.only(top: NpSpace.md, bottom: NpSpace.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? NpColors.accentDefault
                    : NpColors.borderSubtle,
                width: NpSize.tabIndicator,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            tab.label,
            style: NpTypography.tabLabel.copyWith(
              color: isSelected
                  ? NpColors.contentPrimary
                  : NpColors.contentMuted,
            ),
          ),
        ),
      ),
    );
  }
}
