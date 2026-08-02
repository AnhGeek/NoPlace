import 'package:flutter/material.dart';

import '../theme/np_typography.dart';
import '../tokens/design_tokens.g.dart';

/// The heading of a list screen: title on the left, a quiet counter on the
/// right ("2 / 12 districts", "3 active").
///
/// Deliberately not an `AppBar`: these screens scroll under the status bar and
/// an elevated bar would cut the content in two.
class NpScreenHeader extends StatelessWidget {
  const NpScreenHeader({
    required this.title,
    this.trailingText,
    this.action,
    super.key,
  });

  final String title;
  final String? trailingText;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: NpSpace.xs, bottom: NpSpace.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: NpTypography.display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (trailingText != null)
            Text(trailingText!, style: NpTypography.footnote),
          if (action != null) ...[const SizedBox(width: NpSpace.xs), action!],
        ],
      ),
    );
  }
}

/// A round avatar placeholder. Swapped for a real image once profiles carry
/// photos; the border and glow stay the same either way.
class NpAvatar extends StatelessWidget {
  const NpAvatar({this.size = NpSize.avatar, this.imageProvider, super.key});

  final double size;
  final ImageProvider<Object>? imageProvider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFF3A3A44), Color(0xFF1C1C22)],
        ),
        image: imageProvider == null
            ? null
            : DecorationImage(image: imageProvider!, fit: BoxFit.cover),
        border: Border.all(
          color: NpColors.borderOnMedia,
          width: NpBorderWidth.heavy,
        ),
        boxShadow: const [NpShadows.card],
      ),
      alignment: Alignment.center,
      child: imageProvider != null
          ? null
          : Icon(
              Icons.person_outline_rounded,
              size: size * 0.44,
              color: NpColors.contentMuted,
            ),
    );
  }
}
