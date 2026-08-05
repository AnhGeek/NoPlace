import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/home_shell.dart';
import '../../../data/local/backup_service.dart';
import '../../../data/local/document_channel.dart';
import '../../../data/repository_providers.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/theme/np_typography.dart';
import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../l10n/l10n.dart';

/// Getting the walk off the phone, and back onto one.
///
/// The screen leads with what is at stake rather than with its two buttons: the
/// fog is the only thing in the app that cannot be re-earned, and somebody who
/// has never lost a phone has no reason to guess that it lives in exactly one
/// place. The counts underneath are the same argument in numbers.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  /// The system's save and open dialogs.
  static const DocumentChannel _documents = DocumentChannel();

  /// What is on the device, read once when the screen opens and again after a
  /// restore. A future rather than a stream: it counts rows, and rows only
  /// change here.
  late Future<BackupContents> _contents;

  /// Both buttons are disabled while either is working. Exporting reads the
  /// same tables a restore writes, and a save dialog on top of a file picker is
  /// not a state anybody meant to be in.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _contents = ref.read(backupServiceProvider).currentContents();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsBackupTitle)),
      body: ListView(
        // Same shell, same navigation bar over the body: without the inset the
        // last button sits under it.
        padding: EdgeInsets.fromLTRB(
          NpSpace.lg,
          NpSpace.lg,
          NpSpace.lg,
          HomeShell.bottomInsetFor(context),
        ),
        children: [
          Text(l10n.backupIntro, style: NpTypography.body),
          const SizedBox(height: NpSpace.xl),

          Text(
            l10n.backupHolds,
            style: NpTypography.footnote.copyWith(color: NpColors.contentMuted),
          ),
          const SizedBox(height: NpSpace.xs),
          FutureBuilder<BackupContents>(
            future: _contents,
            builder: (context, snapshot) {
              // No spinner while it counts: the card is three lines of text and
              // a flash of empty rows is quieter than a flash of a loader.
              final contents = snapshot.data ?? const BackupContents.empty();
              return NpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ContentsRow(
                      icon: Icons.blur_on_rounded,
                      label: l10n.backupFogCells(contents.trailPoints),
                    ),
                    const SizedBox(height: NpSpace.sm),
                    _ContentsRow(
                      icon: Icons.push_pin_outlined,
                      label: l10n.backupPoints(contents.mapPoints),
                    ),
                    const SizedBox(height: NpSpace.sm),
                    _ContentsRow(
                      icon: Icons.map_outlined,
                      label: l10n.backupRegions(contents.regions.length),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: NpSpace.sm),
          Text(l10n.backupPhotosNote, style: NpTypography.caption),

          const SizedBox(height: NpSpace.xl),
          // Both are dead where there is no save dialog behind them — which
          // today is anything that is not Android. A disabled button says that
          // more honestly than one that does nothing when tapped.
          NpPrimaryButton(
            label: l10n.backupSaveAction,
            icon: Icons.save_alt_rounded,
            onPressed: _busy || !_documents.isSupported ? null : _save,
          ),
          const SizedBox(height: NpSpace.lg),
          NpGhostButton(
            label: l10n.backupRestoreAction,
            onPressed: _busy || !_documents.isSupported ? null : _restore,
          ),
          const SizedBox(height: NpSpace.xs),
          Text(l10n.backupRestoreNote, style: NpTypography.caption),
        ],
      ),
    );
  }

  /// Writes the backup wherever the player says.
  ///
  /// The bytes are handed to the system save dialog rather than written
  /// somewhere of our choosing: from Android 11 the app's own storage is not
  /// reachable from a file manager, so a backup we filed ourselves would be one
  /// the player could not actually get at — which is the entire point of it.
  Future<void> _save() async {
    final l10n = context.l10n;
    final service = ref.read(backupServiceProvider);

    setState(() => _busy = true);
    try {
      final saved = await _documents.save(
        fileName: service.suggestedFileName(),
        bytes: await service.export(),
        // Accurate, and it is what makes the file openable from a file manager
        // and attachable to an email. `.noplace` has no registered type of its
        // own, and inventing one would only hide it from everything.
        mimeType: 'application/gzip',
      );
      // False is the player closing the dialog. Saying nothing is right: they
      // know what they just did.
      if (!saved) return;

      _say(l10n.backupSaved);
    } on Object catch (error) {
      debugPrint('Backup: could not be saved ($error)');
      _say(l10n.backupFailedSave);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Reads a backup back in.
  Future<void> _restore() async {
    final l10n = context.l10n;
    final service = ref.read(backupServiceProvider);

    setState(() => _busy = true);
    try {
      final bytes = await _documents.open();
      if (bytes == null) return;

      final restored = await service.import(bytes);

      if (!mounted) return;
      setState(() => _contents = service.currentContents());
      _say(l10n.backupRestored(restored.trailPoints, restored.mapPoints));
    } on BackupFormatException catch (failure) {
      _say(switch (failure.problem) {
        BackupProblem.notABackup => l10n.backupFailedNotABackup,
        BackupProblem.tooNew => l10n.backupFailedTooNew,
      });
    } on Object catch (error) {
      debugPrint('Backup: could not be restored ($error)');
      _say(l10n.backupFailedRestore);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// One line of "what is in the backup".
class _ContentsRow extends StatelessWidget {
  const _ContentsRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: NpSize.iconLg, color: NpColors.contentMuted),
        const SizedBox(width: NpSpace.sm),
        Expanded(child: Text(label, style: NpTypography.body)),
      ],
    );
  }
}
