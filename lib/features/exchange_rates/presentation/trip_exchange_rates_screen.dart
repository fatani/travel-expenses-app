import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/app_surfaces.dart';
import '../../../core/finance/manual_exchange_rate.dart';
import '../../../core/design_system/calm_snackbar.dart';
import '../../../core/providers/database_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';

class TripExchangeRatesScreen extends ConsumerStatefulWidget {
  const TripExchangeRatesScreen({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<TripExchangeRatesScreen> createState() =>
      _TripExchangeRatesScreenState();
}

class _TripExchangeRatesScreenState
    extends ConsumerState<TripExchangeRatesScreen> {
  late Future<List<ManualExchangeRate>> _ratesFuture;

  @override
  void initState() {
    super.initState();
    _ratesFuture = _loadRates();
  }

  Future<List<ManualExchangeRate>> _loadRates() {
    return ref
        .read(manualExchangeRateRepositoryProvider)
        .listLatestTripRates(widget.trip.id);
  }

  Future<void> _refreshRates() async {
    final refreshed = _loadRates();
    setState(() {
      _ratesFuture = refreshed;
    });
    await refreshed;
  }

  Future<void> _openEditor({ManualExchangeRate? existing}) async {
    final l10n = AppLocalizations.of(context)!;
    final fromController = TextEditingController(
      text: existing?.fromCurrency ?? '',
    );
    final toController = TextEditingController(
      text: existing?.toCurrency ?? widget.trip.homeCurrencySnapshot,
    );
    final rateController = TextEditingController(
      text: existing == null ? '' : existing.rate.toString(),
    );
    final noteController = TextEditingController(text: existing?.sourceNote ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        String? validationError;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomInset),
              child: AppBottomSheetContainer(
                minHeight: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      existing == null
                          ? l10n.tripExchangeRatesAddRate
                          : l10n.tripExchangeRatesEditRate,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: fromController,
                      enabled: !isSaving,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: l10n.tripExchangeRatesFromCurrency,
                        hintText: 'USD',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: toController,
                      enabled: !isSaving,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: l10n.tripExchangeRatesToCurrency,
                        hintText: 'SAR',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rateController,
                      enabled: !isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.tripExchangeRatesRate,
                        hintText: '3.75',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      enabled: !isSaving,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: l10n.tripExchangeRatesSourceNote,
                        hintText: l10n.tripExchangeRatesSourceHint,
                      ),
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        validationError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: Text(l10n.commonCancel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                              final from = fromController.text.trim().toUpperCase();
                              final to = toController.text.trim().toUpperCase();
                              final parsedRate = double.tryParse(
                                rateController.text.trim(),
                              );

                              if (from.length != 3 || to.length != 3) {
                                setSheetState(() {
                                  validationError =
                                      l10n.tripExchangeRatesValidationCurrency;
                                });
                                return;
                              }
                              if (parsedRate == null || parsedRate <= 0) {
                                setSheetState(() {
                                  validationError =
                                      l10n.tripExchangeRatesValidationRate;
                                });
                                return;
                              }

                              setSheetState(() {
                                validationError = null;
                                isSaving = true;
                              });

                              try {
                                await ref
                                    .read(manualExchangeRateRepositoryProvider)
                                    .saveRate(
                                      ManualExchangeRate.create(
                                        tripId: widget.trip.id,
                                        fromCurrency: from,
                                        toCurrency: to,
                                        rate: parsedRate,
                                        sourceNote: noteController.text,
                                      ),
                                    );
                              } catch (_) {
                                if (!sheetContext.mounted) {
                                  return;
                                }

                                setSheetState(() {
                                  validationError =
                                      l10n.tripExchangeRatesSaveError;
                                  isSaving = false;
                                });
                                return;
                              }

                              if (!sheetContext.mounted) {
                                return;
                              }

                              Navigator.of(sheetContext).pop(true);
                            },
                            child: Text(l10n.tripDetailsQuickAddSave),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    fromController.dispose();
    toController.dispose();
    rateController.dispose();
    noteController.dispose();

    if (saved == true && mounted) {
      try {
        await _refreshRates();
      } catch (_) {
        if (!mounted) {
          return;
        }
        final refreshedL10n = AppLocalizations.of(context)!;
        CalmSnackBar.showMessage(
          context,
          message: refreshedL10n.tripExchangeRatesLoadError,
        );
        return;
      }
      if (!mounted) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tripExchangeRatesTitle),
      ),
      body: FutureBuilder<List<ManualExchangeRate>>(
        future: _ratesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(l10n.tripExchangeRatesLoadError));
          }

          final rates = snapshot.data ?? const <ManualExchangeRate>[];
          if (rates.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tripExchangeRatesEmptyTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.tripExchangeRatesEmptyBody,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          final formatter = DateFormat('dd MMM yyyy • HH:mm');

          return RefreshIndicator(
            onRefresh: _refreshRates,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                AppCard(
                  child: Text(
                    l10n.tripExchangeRatesSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 10),
                for (final rate in rates) ...[
                  AppCard(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openEditor(existing: rate),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n.tripExchangeRatesToCurrency,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                Text(
                                  rate.toCurrency,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.tripExchangeRatesRatePreview(
                                rate.fromCurrency,
                                _formatEstimateRate(rate.rate),
                                rate.toCurrency,
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatter.format(rate.createdAt.toLocal()),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if ((rate.sourceNote ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                rate.sourceNote!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.add),
        label: Text(l10n.tripExchangeRatesAddRate),
      ),
    );
  }
}

String _formatEstimateRate(double rate) {
  if (rate >= 100) {
    return rate.toStringAsFixed(2);
  }
  if (rate >= 1) {
    return rate.toStringAsFixed(3);
  }
  return rate.toStringAsFixed(4);
}
