import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../cash_wallet/domain/trip_cash_balance.dart';

/// Read-only cash wallet balances for a trip (independent of report calculations).
final tripCashBalancesProvider =
    FutureProvider.autoDispose.family<List<TripCashBalance>, String>((
  ref,
  tripId,
) async {
  final repository = ref.watch(cashWalletRepositoryProvider);
  return repository.getBalancesByTrip(tripId);
});

/// Balances with a strictly positive amount — used for the trip report snapshot.
List<TripCashBalance> tripPositiveCashBalances(List<TripCashBalance> balances) {
  return balances
      .where((balance) => balance.balanceAmount > 0)
      .toList(growable: false);
}
