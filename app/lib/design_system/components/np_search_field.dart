import 'package:flutter/material.dart';

import '../theme/np_typography.dart';
import '../tokens/design_tokens.g.dart';

/// The floating search bar that sits over the map.
///
/// Translucent on purpose: the map has to stay legible underneath it.
class NpSearchField extends StatelessWidget {
  const NpSearchField({
    required this.hintText,
    this.controller,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    super.key,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  /// When the field is only a button that opens a search screen.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NpSpace.lg,
        vertical: NpSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: NpColors.backgroundPanel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(NpRadius.xxl),
        border: Border.all(
          color: NpColors.borderSubtle,
          width: NpBorderWidth.hairline,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: NpSize.iconMd,
            color: NpColors.contentPlaceholder,
          ),
          const SizedBox(width: NpSpace.sm),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onTap: onTap,
              readOnly: readOnly,
              style: NpTypography.body,
              cursorColor: NpColors.accentDefault,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: NpSpace.sm,
                ),
                hintText: hintText,
                hintStyle: NpTypography.body.copyWith(
                  color: NpColors.contentPlaceholder,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
