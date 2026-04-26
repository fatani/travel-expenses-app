import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../expenses/domain/expense.dart';
import '../../trips/domain/trip.dart';
import '../domain/export_result.dart';

typedef ExportDirectoryProvider = Future<Directory> Function();

class TripCsvExporter {
  TripCsvExporter({ExportDirectoryProvider? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationDocumentsDirectory;

  final ExportDirectoryProvider _directoryProvider;

  static const List<String> _headers = <String>[
    'Trip name',
    'Expense date',
    'Merchant / title',
    'Category',
    'Payment channel',
    'Payment network',
    'Transaction amount',
    'Transaction currency',
    'Billed amount',
    'Billed currency',
    'Fees amount',
    'Fees currency',
    'Notes',
  ];

  String buildCsv({required Trip trip, required List<Expense> expenses}) {
    final buffer = StringBuffer()..write('\uFEFF');

    buffer.writeln(_buildRow(_headers));

    for (final expense in expenses) {
      buffer.writeln(
        _buildRow(<String>[
          trip.name,
          _formatDate(expense.spentAt),
          expense.title,
          expense.category ?? '',
          expense.paymentChannel ?? '',
          expense.paymentNetwork ?? '',
          _formatAmount(expense.transactionAmount),
          expense.transactionCurrency,
          _formatNullableAmount(expense.billedAmount),
          expense.billedCurrency ?? '',
          _formatNullableAmount(expense.feesAmount),
          expense.feesCurrency ?? '',
          expense.note ?? '',
        ]),
      );
    }

    return buffer.toString();
  }

  List<int> buildCsvBytes({required Trip trip, required List<Expense> expenses}) {
    return utf8.encode(buildCsv(trip: trip, expenses: expenses));
  }

  Future<ExportResult> exportTrip({
    required Trip trip,
    required List<Expense> expenses,
  }) async {
    final rootDirectory = await _directoryProvider();
    final exportDirectory = Directory(p.join(rootDirectory.path, 'exports'));
    await exportDirectory.create(recursive: true);

    final now = DateTime.now();
    final fileName = _buildExportFileName(tripName: trip.name, now: now);
    final filePath = p.join(exportDirectory.path, fileName);
    final file = File(filePath);

    await file.writeAsBytes(buildCsvBytes(trip: trip, expenses: expenses), flush: true);

    return ExportResult(
      fileName: fileName,
      filePath: filePath,
      rowCount: expenses.length,
    );
  }

  String _buildRow(List<String> values) {
    return values.map(_escapeCsvCell).join(',');
  }

  String _escapeCsvCell(String value) {
    if (value.isEmpty) {
      return '';
    }

    final escaped = value.replaceAll('"', '""');
    final needsQuotes =
        escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r');

    return needsQuotes ? '"$escaped"' : escaped;
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date.toLocal());
  }

  String _formatAmount(double amount) {
    if (amount == amount.truncateToDouble()) {
      return amount.toStringAsFixed(0);
    }

    return amount.toStringAsFixed(2);
  }

  String _formatNullableAmount(double? amount) {
    if (amount == null) {
      return '';
    }

    return _formatAmount(amount);
  }

  String _buildExportFileName({required String tripName, required DateTime now}) {
    final safeTripName = _sanitizeFileName(tripName);
    final year = DateFormat('yyyy').format(now);
    final exportDate = DateFormat('yyyy-MM-dd').format(now);

    return '${safeTripName}_${year}_Expenses_$exportDate.csv';
  }

  String _sanitizeFileName(String value) {
    final sanitized = value
        .trim()
        // Keep Arabic letters, Latin letters, digits, spaces, underscores, and dashes.
        .replaceAll(RegExp(r'[^\u0600-\u06FFa-zA-Z0-9 _-]+'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return sanitized.isEmpty ? 'trip_expenses' : sanitized;
  }
}