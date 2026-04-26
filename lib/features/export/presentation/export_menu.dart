import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/database_providers.dart';
import '../../trips/domain/trip.dart';
import '../data/trip_csv_exporter.dart';
import '../data/trip_pdf_exporter.dart';

enum _ExportType { csv, pdf }

/// A popup-menu AppBar action that offers both CSV and PDF export for a trip.
class ExportMenu extends ConsumerWidget {
  const ExportMenu({super.key, required this.trip, required this.enabled});

  final Trip trip;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_ExportType>(
      enabled: enabled,
      icon: const Icon(Icons.file_download_outlined),
      tooltip: 'تصدير',
      onSelected: (type) => _handleExport(context, ref, type),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _ExportType.csv,
          child: Text('تصدير CSV'),
        ),
        PopupMenuItem(
          value: _ExportType.pdf,
          child: Text('تصدير PDF'),
        ),
      ],
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    WidgetRef ref,
    _ExportType type,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final expenses = await ref
          .read(expenseRepositoryProvider)
          .getExpensesByTrip(trip.id);

      if (expenses.isEmpty) {
        if (!context.mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('لا توجد مصاريف لتصديرها.')),
        );
        return;
      }

      final String filePath;
      final String fileName;

      if (type == _ExportType.csv) {
        final result = await TripCsvExporter().exportTrip(
          trip: trip,
          expenses: expenses,
        );
        filePath = result.filePath;
        fileName = result.fileName;
      } else {
        final result = await TripPdfExporter().exportTrip(
          trip: trip,
          expenses: expenses,
        );
        filePath = result.filePath;
        fileName = result.fileName;
      }

      if (!context.mounted) return;

      await Share.shareXFiles([XFile(filePath)], subject: fileName);

      if (!context.mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('تم تصدير الملف بنجاح')),
      );
    } catch (error) {
      if (!context.mounted) return;
      final label = type == _ExportType.csv ? 'CSV' : 'PDF';
      messenger.showSnackBar(
        SnackBar(content: Text('تعذر تصدير $label: $error')),
      );
    }
  }
}
