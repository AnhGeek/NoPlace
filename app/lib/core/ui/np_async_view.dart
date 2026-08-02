import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/theme/np_typography.dart';
import '../../design_system/tokens/design_tokens.g.dart';

/// Renders an [AsyncValue] with the app's one loading state and one error
/// state.
///
/// Every screen goes through this, so "still loading" and "it broke" look the
/// same everywhere and no feature invents its own spinner.
class NpAsyncView<T> extends StatelessWidget {
  const NpAsyncView({
    required this.value,
    required this.data,
    this.loading,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// Optional skeleton. Falls back to a centred spinner.
  final Widget? loading;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: data,
      loading: () =>
          loading ??
          const Center(
            child: SizedBox(
              width: NpSize.iconXl,
              height: NpSize.iconXl,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      error: (error, stackTrace) => _ErrorView(onRetry: onRetry),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NpSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: NpSize.iconHero,
              color: NpColors.contentMuted,
            ),
            const SizedBox(height: NpSpace.md),
            Text(
              // Not localised on purpose yet: the copy for failure states is
              // still open, and a wrong sentence in two languages is worse than
              // a neutral one in English. Tracked in docs/backlog.md.
              'Something went wrong.',
              style: NpTypography.body.copyWith(color: NpColors.contentMuted),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: NpSpace.md),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
