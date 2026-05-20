import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/database_providers.dart';
import '../../trips/domain/trip.dart';
import '../data/trip_csv_exporter.dart';

class ExportTripButton extends ConsumerWidget {
  const ExportTripButton({
    super.key,
    required this.trip,
    required this.enabled,
  });

  final Trip trip;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: enabled ? () => _exportTrip(context, ref) : null,
      icon: const Icon(Icons.file_download_outlined),
      label: const Text('\u062a\u0635\u062f\u064a\u0631 CSV'),
    );
  }

  Future<void> _exportTrip(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final expenses = await ref.read(expenseRepositoryProvider).getExpensesByTrip(
        trip.id,
      );

      if (expenses.isEmpty) {
        if (!context.mounted) {
          return;
        }

        messenger.showSnackBar(
          const SnackBar(content: Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0635\u0627\u0631\u064a\u0641 \u0644\u062a\u0635\u062f\u064a\u0631\u0647\u0627.')),
        );
        return;
      }

      final exporter = TripCsvExporter();
      final result = await exporter.exportTrip(trip: trip, expenses: expenses);
      if (!context.mounted) {
        return;
      }

      await Share.shareXFiles(
        [XFile(result.filePath)],
        subject: result.fileName,
      );

      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('\u062a\u0645 \u062a\u0635\u062f\u064a\u0631 \u0627\u0644\u0645\u0644\u0641 \u0628\u0646\u062c\u0627\u062d')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('\u062a\u0639\u0630\u0631 \u062a\u0635\u062f\u064a\u0631 CSV: $error')),
      );
    }
  }
}
