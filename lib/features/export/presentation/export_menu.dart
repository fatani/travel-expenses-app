import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';
import 'package:travel_expenses/l10n/l10n_extension.dart';

import '../../../core/design_system/calm_snackbar.dart';
import '../../../core/providers/database_providers.dart';
import '../../trips/domain/trip.dart';
import '../../trips/domain/trip_title_resolver.dart';
import '../data/trip_csv_exporter.dart';
import '../data/trip_pdf_exporter.dart';
import 'trip_export_guard.dart';

enum TripExportFormat { csv, pdf }

Future<void> handleTripExport(
  BuildContext context,
  WidgetRef ref, {
  required Trip trip,
  required TripExportFormat format,
}) async {
  final formatKey = format == TripExportFormat.csv ? 'csv' : 'pdf';
  if (!TripExportGuard.tryAcquire(tripId: trip.id, formatKey: formatKey)) {
    return;
  }

  final l10n = AppLocalizations.of(context)!;
  CalmSnackBar.clear(context);

  // Resolve the trip title based on the active locale before any async gap.
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
      CalmSnackBar.showMessage(context, message: l10n.exportNoExpenses);
      return;
    }

    final String filePath;
    final String fileName;

    if (format == TripExportFormat.csv) {
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
  } catch (error) {
    if (!context.mounted) return;
    final label = format == TripExportFormat.csv ? 'CSV' : 'PDF';
    CalmSnackBar.showMessage(
      context,
      message: l10n.exportFailed(label),
    );
  } finally {
    TripExportGuard.release(tripId: trip.id, formatKey: formatKey);
  }
}

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
    final l10n = context.l10n;

    return PopupMenuButton<TripExportFormat>(
      enabled: enabled,
      icon: trigger == null ? const Icon(Icons.file_download_outlined) : null,
      padding: EdgeInsets.zero,
      tooltip: l10n.exportMenuTooltip,
      onSelected: (format) => handleTripExport(
        context,
        ref,
        trip: trip,
        format: format,
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: TripExportFormat.csv,
          child: Text(l10n.exportMenuCsv),
        ),
        PopupMenuItem(
          value: TripExportFormat.pdf,
          child: Text(l10n.exportMenuPdf),
        ),
      ],
      child: trigger,
    );
  }
}
