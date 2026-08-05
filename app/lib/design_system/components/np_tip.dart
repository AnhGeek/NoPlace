import 'package:flutter/material.dart';

import '../theme/np_typography.dart';
import '../tokens/design_tokens.g.dart';
import 'np_button.dart';
import 'np_sheet.dart';

/// A question mark that explains the control it sits beside.
///
/// For settings whose *name* cannot carry their meaning — anything that will
/// keep acting on the player's behalf after they have put the phone away. The
/// alternative is a paragraph under every such control, which nobody reads
/// twice and which pushes the buttons off the screen.
///
/// Deliberately not a [Tooltip]: a long press that shows text for two seconds
/// is a poor way to read three paragraphs, and it is invisible to anyone who
/// does not know the gesture exists. This is a button, it looks like a button,
/// and what it opens can be read at leisure and dismissed on purpose.
class NpTipButton extends StatelessWidget {
  const NpTipButton({
    required this.title,
    required this.body,
    required this.semanticLabel,
    required this.dismissLabel,
    super.key,
  });

  /// What the tip is about, in a few words.
  final String title;

  /// The explanation. Blank lines become paragraph breaks.
  final String body;

  /// Read out in place of the glyph, which says nothing on its own. Doubles as
  /// the tooltip on a long press.
  final String semanticLabel;

  /// Closes the tip. Passed in rather than read from `MaterialLocalizations`,
  /// because the design system does not get to decide the app's voice — and
  /// "OK" is not the same register as the rest of these sheets.
  final String dismissLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        excludeFromSemantics: true,
        child: InkResponse(
          onTap: () => showNpTip(
            context: context,
            title: title,
            body: body,
            dismissLabel: dismissLabel,
          ),
          radius: NpSize.iconLg,
          child: const Padding(
            // Padded rather than sized, so the glyph stays small next to a
            // section label while the tap target does not.
            padding: EdgeInsets.all(NpSpace.xs),
            child: Icon(
              Icons.help_outline_rounded,
              size: NpSize.iconMd,
              color: NpColors.contentMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a tip as a sheet. Exposed on its own so a screen can explain something
/// that has no control to hang a [NpTipButton] off.
Future<void> showNpTip({
  required BuildContext context,
  required String title,
  required String body,
  required String dismissLabel,
}) {
  return showNpModalSheet<void>(
    context: context,
    builder: (context) => NpSheetSurface(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.help_outline_rounded,
                  size: NpSize.iconLg,
                  color: NpColors.accentDefault,
                ),
                const SizedBox(width: NpSpace.sm),
                Expanded(child: Text(title, style: NpTypography.title)),
              ],
            ),
            const SizedBox(height: NpSpace.md),
            Text(body, style: NpTypography.body),
            const SizedBox(height: NpSpace.lg),
            NpPrimaryButton(
              label: dismissLabel,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
