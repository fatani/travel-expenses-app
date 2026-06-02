import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:travel_expenses/l10n/l10n_extension.dart';

import '../../../app/app_router.dart';
import '../../../core/design_system/calm_snackbar.dart';
import '../domain/backup_restore_failure.dart';
import '../domain/backup_restore_preview.dart';
import 'backup_providers.dart';
import 'backup_restore_messages.dart';
import 'backup_restore_picked_file.dart';
import 'backup_restore_provider_refresh.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isExporting = false;
  bool _isPickingRestoreFile = false;
  bool _isRestoring = false;
  BackupRestorePreview? _preview;

  Future<void> _createBackup() async {
    if (_isExporting || _isRestoring) {
      return;
    }

    setState(() => _isExporting = true);
    CalmSnackBar.clear(context);

    final l10n = context.l10n;

    try {
      final result = await ref.read(backupExportServiceProvider).export();

      if (!mounted) {
        return;
      }

      await Share.shareXFiles(
        [XFile(result.filePath)],
        subject: result.fileName,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      CalmSnackBar.showMessage(context, message: l10n.backupExportFailed);
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _pickRestoreFile() async {
    if (_isPickingRestoreFile || _isRestoring || _isExporting) {
      return;
    }

    setState(() {
      _isPickingRestoreFile = true;
      _preview = null;
    });
    CalmSnackBar.clear(context);

    final l10n = context.l10n;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['clbackup'],
        withData: true,
      );

      if (!mounted) {
        return;
      }

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final fileName = file.name;

      List<int>? bytes;
      try {
        bytes = await readRestorePickedFileBytes(file);
      } catch (error, stackTrace) {
        debugPrint('backup restore pick failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (!mounted) {
          return;
        }
        CalmSnackBar.showMessage(context, message: l10n.backupRestoreSelectFailed);
        return;
      }

      if (bytes == null) {
        if (!mounted) {
          return;
        }
        CalmSnackBar.showMessage(context, message: l10n.backupRestoreSelectFailed);
        return;
      }

      final contents = String.fromCharCodes(bytes);
      final preview = ref.read(backupRestoreServiceProvider).loadPreview(
            fileName: fileName,
            contents: contents,
          );

      setState(() => _preview = preview);
    } on BackupRestoreException catch (error) {
      if (!mounted) {
        return;
      }
      CalmSnackBar.showMessage(
        context,
        message: backupRestoreFailureMessage(l10n, error),
      );
    } catch (error, stackTrace) {
      debugPrint('backup restore pick failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      CalmSnackBar.showMessage(context, message: l10n.backupRestoreSelectFailed);
    } finally {
      if (mounted) {
        setState(() => _isPickingRestoreFile = false);
      }
    }
  }

  Future<void> _confirmAndRestore() async {
    final preview = _preview;
    if (preview == null || _isRestoring) {
      return;
    }

    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.backupRestoreConfirmTitle),
          content: Text(l10n.backupRestoreConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.backupRestoreCancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.backupRestoreConfirmButton),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isRestoring = true);
    CalmSnackBar.clear(context);

    try {
      await ref
          .read(backupRestoreServiceProvider)
          .restore(preview.envelope);

      if (!mounted) {
        return;
      }

      refreshProvidersAfterRestore(ref);

      setState(() => _preview = null);

      CalmSnackBar.showMessage(context, message: l10n.backupRestoreSuccess);

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.home,
        (route) => false,
      );
    } on BackupRestoreException catch (error) {
      if (!mounted) {
        return;
      }
      CalmSnackBar.showMessage(
        context,
        message: backupRestoreFailureMessage(l10n, error),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      CalmSnackBar.showMessage(context, message: l10n.backupRestoreFailed);
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preview = _preview;
    final locale = Localizations.localeOf(context).toString();
    final exportedAtLabel = preview == null
        ? null
        : DateFormat.yMMMd(locale).add_jm().format(preview.exportedAt.toLocal());

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: Text(l10n.backupRestoreTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _InfoCard(
            children: [
              Text(
                l10n.backupLocalDataNotice,
                style: _infoTextStyle,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.backupCreatesFileNotice,
                style: _infoTextStyle,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.backupNoCloudSyncNotice,
                style: _infoTextStyle,
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isExporting || _isRestoring ? null : _createBackup,
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.backup_outlined),
            label: Text(l10n.backupCreateButton),
            style: _primaryButtonStyle,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isPickingRestoreFile || _isRestoring || _isExporting
                ? null
                : _pickRestoreFile,
            icon: _isPickingRestoreFile
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore_outlined),
            label: Text(l10n.backupRestoreButton),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (preview != null) ...[
            const SizedBox(height: 20),
            _InfoCard(
              children: [
                Text(
                  l10n.backupRestorePreviewTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.backupRestorePreviewExportedAt(exportedAtLabel!),
                  style: _infoTextStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.backupRestorePreviewSchemaVersion(preview.schemaVersion),
                  style: _infoTextStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.backupRestorePreviewTripCount(preview.tripCount),
                  style: _infoTextStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.backupRestorePreviewExpenseCount(preview.expenseCount),
                  style: _infoTextStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.backupRestorePreviewCashTransactionCount(
                    preview.cashTransactionCount,
                  ),
                  style: _infoTextStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.backupRestorePreviewCardCount(preview.cardCount),
                  style: _infoTextStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.backupRestorePreviewManualExchangeRateCount(
                    preview.manualExchangeRateCount,
                  ),
                  style: _infoTextStyle,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isRestoring ? null : _confirmAndRestore,
              icon: _isRestoring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.warning_amber_rounded),
              label: Text(
                _isRestoring
                    ? l10n.backupRestoreInProgress
                    : l10n.backupRestoreConfirmButton,
              ),
              style: _primaryButtonStyle.copyWith(
                backgroundColor: WidgetStateProperty.all(
                  const Color(0xFFB45309),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static final _primaryButtonStyle = FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(52),
    backgroundColor: const Color(0xFF2563EB),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );

  static const _infoTextStyle = TextStyle(
    fontSize: 15,
    height: 1.45,
    color: Color(0xFF475569),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6EAF4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
