import 'cash_transaction.dart';
import 'trip_cash_balance.dart';

/// Recomputes [TripCashBalance] rows from raw cash transaction maps.
///
/// Uses [CashTransactionType.signedDelta] semantics, skips reversed rows, and
/// supports multiple trips and currencies deterministically (stable sort).
abstract final class CashBalanceRecompute {
  /// Keys are `tripId`, then `currencyCode` (uppercase), then balance amount.
  static Map<String, Map<String, double>> recomputeBalancesFromTransactions(
    Iterable<Map<String, dynamic>> cashTransactionRows,
  ) {
    final balances = <String, Map<String, double>>{};

    final sortedRows = cashTransactionRows.toList()
      ..sort((a, b) {
        final tripCompare = _readString(a, 'trip_id').compareTo(
          _readString(b, 'trip_id'),
        );
        if (tripCompare != 0) {
          return tripCompare;
        }
        final currencyCompare = _readCurrency(a).compareTo(_readCurrency(b));
        if (currencyCompare != 0) {
          return currencyCompare;
        }
        final createdCompare = _readString(a, 'created_at').compareTo(
          _readString(b, 'created_at'),
        );
        if (createdCompare != 0) {
          return createdCompare;
        }
        return _readString(a, 'id').compareTo(_readString(b, 'id'));
      });

    for (final row in sortedRows) {
      if (_isReversed(row)) {
        continue;
      }

      final tripId = _readString(row, 'trip_id');
      final currencyCode = _readCurrency(row);
      final amount = (row['amount'] as num).toDouble();
      final type = CashTransactionTypeCodec.fromValue(
        _readString(row, 'type'),
      );
      final delta = type.signedDelta(amount);

      final byCurrency = balances.putIfAbsent(tripId, () => {});
      byCurrency[currencyCode] = (byCurrency[currencyCode] ?? 0) + delta;
    }

    return balances;
  }

  /// Materializes balance maps as [TripCashBalance] list sorted by trip then currency.
  static List<TripCashBalance> recomputeTripCashBalances(
    Iterable<Map<String, dynamic>> cashTransactionRows, {
    DateTime? updatedAt,
  }) {
    final at = (updatedAt ?? DateTime.now()).toUtc();
    final balances = recomputeBalancesFromTransactions(cashTransactionRows);
    final result = <TripCashBalance>[];

    final tripIds = balances.keys.toList()..sort();
    for (final tripId in tripIds) {
      final currencies = balances[tripId]!;
      final currencyCodes = currencies.keys.toList()..sort();
      for (final currencyCode in currencyCodes) {
        result.add(
          TripCashBalance(
            tripId: tripId,
            currencyCode: currencyCode,
            balanceAmount: currencies[currencyCode]!,
            updatedAt: at,
          ),
        );
      }
    }

    return result;
  }

  static bool _isReversed(Map<String, dynamic> row) {
    final raw = row['is_reversed'];
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt() == 1;
    }
    return false;
  }

  static String _readString(Map<String, dynamic> row, String key) {
    return row[key]! as String;
  }

  static String _readCurrency(Map<String, dynamic> row) {
    return _readString(row, 'currency_code').trim().toUpperCase();
  }
}
