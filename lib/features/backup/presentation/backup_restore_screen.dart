import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:travel_expenses/l10n/l10n_extension.dart';

import '../../../core/design_system/calm_snackbar.dart';
import 'backup_providers.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isExporting = false;

  Future<void> _createBackup() async {
    if (_isExporting) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
            onPressed: _isExporting ? null : _createBackup,
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
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
