import 'package:flutter/material.dart';

import '../../../../design_system/theme/np_typography.dart';
import '../../../../design_system/tokens/design_tokens.g.dart';
import 'basemap.dart';

/// The credit the map data requires, rendered verbatim.
///
/// This is a licence condition of the tiles, not decoration — see
/// docs/adr/0008-openstreetmap-basemap.md. Two rules follow from that:
///
/// * the text is whatever the pack says and is never edited or abbreviated
///   here, because the app does not know what its data source requires;
/// * it must actually be *visible*. It sits in the map screen's chrome rather
///   than on the map itself, because the bottom of the map — where a credit
///   line conventionally goes — is covered by the nav bar and the check-in
///   card, and a credit behind a nav bar is not a credit.
///
/// An empty attribution renders nothing: a source that requires no credit is a
/// deliberate choice by whoever cooked the pack.
class BasemapAttribution extends StatelessWidget {
  const BasemapAttribution({required this.basemap, super.key});

  final Basemap? basemap;

  @override
  Widget build(BuildContext context) {
    final text = basemap?.info.attribution ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(
          right: NpSpace.lg,
          top: NpSpace.xs,
        ),
        child: Text(
          text,
          style: NpTypography.caption.copyWith(color: NpColors.contentMuted),
        ),
      ),
    );
  }
}
