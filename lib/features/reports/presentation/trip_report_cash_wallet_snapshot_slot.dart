import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/trip_cash_balances_provider.dart';
import 'trip_report_cash_wallet_snapshot.dart';

/// Loads wallet balances and renders [TripReportCashWalletSnapshot] when any
/// balance is strictly positive; otherwise renders nothing.
class TripReportCashWalletSnapshotSlot extends ConsumerWidget {
  const TripReportCashWalletSnapshotSlot({
    super.key,
    required this.tripId,
    this.sectionGap,
  });

  final String tripId;
  final Widget? sectionGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(tripCashBalancesProvider(tripId));

    return balancesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (balances) {
        final positiveBalances = tripPositiveCashBalances(balances);
        if (positiveBalances.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TripReportCashWalletSnapshot(balances: positiveBalances),
            ?sectionGap,
          ],
        );
      },
    );
  }
}
