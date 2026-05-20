import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/database_providers.dart';
import '../../trips/domain/trip.dart';
import '../../trips/domain/trip_title_resolver.dart';
import '../data/trip_csv_exporter.dart';
import '../data/trip_pdf_exporter.dart';

enum _ExportType { csv, pdf }

/// A popup-menu AppBar action that offers both CSV and PDF export for a trip.
class ExportMenu extends ConsumerWidget {
  const ExportMenu({
    super.key,
    required this.trip,
    required this.enabled,
    this.trigger,
  });

  final Trip trip;
  final bool enabled;
  final Widget? trigger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_ExportType>(
      enabled: enabled,
      icon: trigger == null ? const Icon(Icons.file_download_outlined) : null,
      padding: EdgeInsets.zero,
      tooltip: '\u062a\u0635\u062f\u064a\u0631',
      onSelected: (type) => _handleExport(context, ref, type),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _ExportType.csv,
          child: Text('\u062a\u0635\u062f\u064a\u0631 CSV'),
        ),
        PopupMenuItem(
          value: _ExportType.pdf,
          child: Text('\u062a\u0635\u062f\u064a\u0631 PDF'),
        ),
      ],
      child: trigger,
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    WidgetRef ref,
    _ExportType type,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final exportTrip = trip.copyWith(
      name: TripTitleResolver.resolve(trip, isArabic),
    );

    try {
      final expenses = await ref
          .read(expenseRepositoryProvider)
          .getExpensesByTrip(trip.id);

      if (expenses.isEmpty) {
        if (!context.mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0635\u0627\u0631\u064a\u0641 \u0644\u062a\u0635\u062f\u064a\u0631\u0647\u0627.')),
        );
        return;
      }

      final String filePath;
      final String fileName;

      if (type == _ExportType.csv) {
        final result = await TripCsvExporter().exportTrip(
          trip: exportTrip,
          expenses: expenses,
        );
        filePath = result.filePath;
        fileName = result.fileName;
      } else {
        final result = await TripPdfExporter().exportTrip(
          trip: exportTrip,
          expenses: expenses,
        );
        filePath = result.filePath;
        fileName = result.fileName;
      }

      if (!context.mounted) return;

      await Share.shareXFiles([XFile(filePath)], subject: fileName);

      if (!context.mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('\u062a\u0645 \u062a\u0635\u062f\u064a\u0631 \u0627\u0644\u0645\u0644\u0641 \u0628\u0646\u062c\u0627\u062d')),
      );
    } catch (error) {
      if (!context.mounted) return;
      final label = type == _ExportType.csv ? 'CSV' : 'PDF';
      messenger.showSnackBar(
        SnackBar(content: Text('\u062a\u0639\u0630\u0631 \u062a\u0635\u062f\u064a\u0631 $label: $error')),
      );
    }
  }
}
