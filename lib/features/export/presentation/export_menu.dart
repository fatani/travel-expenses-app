import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';
import 'package:travel_expenses/l10n/l10n_extension.dart';

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
    final l10n = context.l10n;

    return PopupMenuButton<_ExportType>(
      enabled: enabled,
      icon: trigger == null ? const Icon(Icons.file_download_outlined) : null,
      padding: EdgeInsets.zero,
      tooltip: l10n.exportMenuTooltip,
      onSelected: (type) => _handleExport(context, ref, type),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _ExportType.csv,
          child: Text(l10n.exportMenuCsv),
        ),
        PopupMenuItem(
          value: _ExportType.pdf,
          child: Text(l10n.exportMenuPdf),
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
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

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
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.exportNoExpenses)),
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
        SnackBar(content: Text(l10n.exportSuccess)),
      );
    } catch (error) {
      if (!context.mounted) return;
      final label = type == _ExportType.csv ? 'CSV' : 'PDF';
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.exportFailed(label, '$error'))),
      );
    }
  }
}
