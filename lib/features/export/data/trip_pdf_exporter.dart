import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../expenses/domain/expense.dart';
import '../../trips/domain/trip.dart';
import '../domain/export_result.dart';

typedef PdfDirectoryProvider = Future<Directory> Function();

/// Generates a trip-summary PDF and saves it to the exports directory.
/// Arabic text is rendered using an embedded NotoSansArabic TTF font with
/// RTL text direction applied to all text widgets.
class TripPdfExporter {
  TripPdfExporter({
    PdfDirectoryProvider? directoryProvider,
    pw.Font? arabicFont,
  }) : _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory,
       _arabicFontOverride = arabicFont;

  final PdfDirectoryProvider _directoryProvider;

  /// Optional font override – used in unit tests to avoid loading from assets.
  final pw.Font? _arabicFontOverride;

  // ─── Public API ───────────────────────────────────────────────────────────

  Future<ExportResult> exportTrip({
    required Trip trip,
    required List<Expense> expenses,
  }) async {
    final bytes = await buildPdfBytes(trip: trip, expenses: expenses);

    final rootDirectory = await _directoryProvider();
    final exportDirectory = Directory(p.join(rootDirectory.path, 'exports'));
    await exportDirectory.create(recursive: true);

    final now = DateTime.now();
    final fileName = _buildFileName(tripName: trip.name, now: now);
    final filePath = p.join(exportDirectory.path, fileName);

    await File(filePath).writeAsBytes(bytes, flush: true);

    return ExportResult(
      fileName: fileName,
      filePath: filePath,
      rowCount: expenses.length,
    );
  }

  Future<List<int>> buildPdfBytes({
    required Trip trip,
    required List<Expense> expenses,
  }) async {
    final font = _arabicFontOverride ?? await _loadArabicFont();
    final doc = _buildDocument(trip: trip, expenses: expenses, font: font);
    return doc.save();
  }

  // ─── Font loader ──────────────────────────────────────────────────────────

  Future<pw.Font> _loadArabicFont() async {
    final data = await rootBundle.load(
      'assets/fonts/NotoSansArabic-Regular.ttf',
    );
    return pw.Font.ttf(data);
  }

  // ─── Document builder ─────────────────────────────────────────────────────

  pw.Document _buildDocument({
    required Trip trip,
    required List<Expense> expenses,
    required pw.Font font,
  }) {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 44),
        build:
            (context) =>
                _buildContent(trip: trip, expenses: expenses, font: font),
      ),
    );
    return doc;
  }

  List<pw.Widget> _buildContent({
    required Trip trip,
    required List<Expense> expenses,
    required pw.Font font,
  }) {
    return [
      _buildHeader(trip, font),
      pw.SizedBox(height: 10),
      pw.Divider(thickness: 1.5),
      pw.SizedBox(height: 14),
      _buildSummarySection(expenses, font),
      pw.SizedBox(height: 14),
      ..._buildBreakdowns(expenses, font),
    ];
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  pw.Widget _buildHeader(Trip trip, pw.Font font) {
    final dateLine = _formatDateRange(trip.startDate, trip.endDate);
    final baseCurrencyLine = trip.baseCurrency.isNotEmpty
      ? trip.baseCurrency
      : '—';
    final citiesLine = _formatCitiesLine(trip.destination);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          trip.name,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            font: font,
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          dateLine,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            font: font,
            fontSize: 11,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(
          baseCurrencyLine,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            font: font,
            fontSize: 11,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(
          citiesLine,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            font: font,
            fontSize: 11,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  // ─── Summary ──────────────────────────────────────────────────────────────

  pw.Widget _buildSummarySection(List<Expense> expenses, pw.Font font) {
    final totalByCurrency = _sumByCurrency(expenses);
    final feesByCurrency = _feesByCurrency(expenses);
    final topCategory = _topCategory(expenses);

    return _buildSection(
      title: 'Summary',
      font: font,
      rows: [
        _row('Total expenses', '${expenses.length}', font),
        ...totalByCurrency.entries.map(
          (e) => _row('Total (${e.key})', _fmt(e.value), font),
        ),
        if (feesByCurrency.isNotEmpty)
          ...feesByCurrency.entries.map(
            (e) => _row('Int\'l fees (${e.key})', _fmt(e.value), font),
          ),
        if (topCategory != null) _row('Top category', topCategory, font),
      ],
    );
  }

  // ─── Breakdown sections ───────────────────────────────────────────────────

  List<pw.Widget> _buildBreakdowns(List<Expense> expenses, pw.Font font) {
    return [
      _buildCategoryBreakdown(expenses, font),
      pw.SizedBox(height: 12),
      _buildCurrencyBreakdown(expenses, font),
      pw.SizedBox(height: 12),
      _buildChannelBreakdown(expenses, font),
      pw.SizedBox(height: 12),
      _buildNetworkBreakdown(expenses, font),
    ];
  }

  pw.Widget _buildCategoryBreakdown(List<Expense> expenses, pw.Font font) {
    final groups = <String, int>{};
    for (final e in expenses) {
      final key =
          e.category?.isNotEmpty == true ? e.category! : 'Uncategorised';
      groups[key] = (groups[key] ?? 0) + 1;
    }
    return _buildSection(
      title: 'By Category',
      font: font,
      rows: _countRows(groups, font),
    );
  }

  pw.Widget _buildCurrencyBreakdown(List<Expense> expenses, pw.Font font) {
    final totals = _sumByCurrency(expenses);
    return _buildSection(
      title: 'By Transaction Currency',
      font: font,
      rows: totals.entries.map((e) => _row(e.key, _fmt(e.value), font)).toList(),
    );
  }

  pw.Widget _buildChannelBreakdown(List<Expense> expenses, pw.Font font) {
    final groups = <String, int>{};
    for (final e in expenses) {
      final key =
          e.paymentChannel?.isNotEmpty == true ? e.paymentChannel! : '—';
      groups[key] = (groups[key] ?? 0) + 1;
    }
    return _buildSection(
      title: 'By Payment Channel',
      font: font,
      rows: _countRows(groups, font),
    );
  }

  pw.Widget _buildNetworkBreakdown(List<Expense> expenses, pw.Font font) {
    final groups = <String, int>{};
    for (final e in expenses) {
      final key =
          e.paymentNetwork?.isNotEmpty == true ? e.paymentNetwork! : '—';
      groups[key] = (groups[key] ?? 0) + 1;
    }
    return _buildSection(
      title: 'By Payment Network',
      font: font,
      rows: _countRows(groups, font),
    );
  }

  // ─── Layout helpers ───────────────────────────────────────────────────────

  pw.Widget _buildSection({
    required String title,
    required pw.Font font,
    required List<pw.Widget> rows,
  }) {
    if (rows.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          title.toUpperCase(),
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            font: font,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey600,
            letterSpacing: 0.8,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Divider(thickness: 0.5),
        ...rows,
      ],
    );
  }

  pw.Widget _row(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            value,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            label,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _countRows(Map<String, int> groups, pw.Font font) {
    return groups.entries
        .map(
          (e) => _row(
            e.key,
            '${e.value} expense${e.value == 1 ? '' : 's'}',
            font,
          ),
        )
        .toList();
  }

  // ─── Aggregation helpers ──────────────────────────────────────────────────

  Map<String, double> _sumByCurrency(List<Expense> expenses) {
    final result = <String, double>{};
    for (final e in expenses) {
      result[e.transactionCurrency] =
          (result[e.transactionCurrency] ?? 0) + e.transactionAmount;
    }
    return result;
  }

  Map<String, double> _feesByCurrency(List<Expense> expenses) {
    final result = <String, double>{};
    for (final e in expenses) {
      final amount = e.feesAmount;
      final currency = e.feesCurrency;
      if (amount != null && amount > 0 && currency != null) {
        result[currency] = (result[currency] ?? 0) + amount;
      }
    }
    return result;
  }

  String? _topCategory(List<Expense> expenses) {
    final counts = <String, int>{};
    for (final e in expenses) {
      if (e.category?.isNotEmpty == true) {
        counts[e.category!] = (counts[e.category!] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ─── Formatting helpers ───────────────────────────────────────────────────

  String _formatDateRange(DateTime? start, DateTime? end) {
    final fmt = DateFormat('yyyy-MM-dd');

    // Enforce safe display order: ensure earlier date is always on the left.
    // Does NOT mutate the data model – render-only fix.
    DateTime? safeStart = start;
    DateTime? safeEnd = end;
    if (safeStart != null && safeEnd != null && safeStart.isAfter(safeEnd)) {
      safeStart = end;
      safeEnd = start;
    }

    final startText = safeStart != null ? fmt.format(safeStart.toLocal()) : '—';
    final endText = safeEnd != null ? fmt.format(safeEnd.toLocal()) : '—';
    return '$startText -> $endText';
  }

  String _formatCitiesLine(String destination) {
    if (destination.trim().isEmpty) return '—';
    final cities = destination
        .split(RegExp(r'\s*(?:,|،|\|)\s*'))
        .map((city) => city.trim())
        .where((city) => city.isNotEmpty)
        .toList();
    if (cities.isEmpty) return '—';
    return cities.join(' - ');
  }

  String _fmt(double value) {
    if (value == value.truncateToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  String _buildFileName({required String tripName, required DateTime now}) {
    final baseName = tripName.trim().replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final safe = baseName
        .trim()
      .replaceAll(RegExp(r'[\\/:]+'), '')
      .replaceAll(RegExp(r'[^\u0600-\u06FFa-zA-Z0-9 _-]+'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final safeName = safe.isEmpty ? 'trip_summary' : safe;
    final exportDate = DateFormat('yyyy-MM-dd').format(now);
    return '${safeName}_Summary_$exportDate.pdf';
  }
}
