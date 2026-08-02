import 'package:flutter/material.dart';

import '../tokens/design_tokens.g.dart';

/// The surface of a bottom sheet: rounded top corners, raised panel colour and
/// the grab handle.
///
/// Pair it with [showNpModalSheet] so every sheet in the app has the same
/// barrier, radius and drag behaviour.
class NpSheetSurface extends StatelessWidget {
  const NpSheetSurface({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      NpSpace.lg,
      NpSpace.md,
      NpSpace.lg,
      NpSpace.xxl,
    ),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: NpColors.backgroundPanelRaised,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NpRadius.sheet),
        ),
        boxShadow: [NpShadows.sheet],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: padding.add(EdgeInsets.only(bottom: bottomInset)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _Grabber()),
              const SizedBox(height: NpSpace.md),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: NpSize.grabber,
      height: NpSpace.xxs,
      decoration: BoxDecoration(
        color: NpColors.borderStrong,
        borderRadius: BorderRadius.circular(NpRadius.pill),
      ),
    );
  }
}

/// Opens [builder] as a modal sheet with the app's standard chrome.
///
/// `useRootNavigator` matters more than it looks: without it the sheet is
/// pushed inside the current tab's navigator and the bottom navigation bar
/// draws *over* it, swallowing the last row of buttons.
Future<T?> showNpModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: Colors.transparent,
    barrierColor: NpColors.backgroundScrim,
    // The surface handles its own safe area, so the sheet can reach the very
    // bottom of the screen instead of floating above the gesture bar.
    useSafeArea: false,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
    ),
    builder: builder,
  );
}
