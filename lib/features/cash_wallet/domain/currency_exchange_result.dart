import 'cash_lot.dart';
import 'cash_lot_consumption.dart';
import 'cash_transaction.dart';
import 'currency_exchange.dart';

/// Immutable result returned by [RecordCurrencyExchangeUseCase.execute].
///
/// All fields reflect the rows that were written to the database inside the
/// atomic transaction.
class CurrencyExchangeResult {
  const CurrencyExchangeResult({
    required this.exchange,
    required this.destinationLot,
    required this.exchangeOutTransaction,
    required this.exchangeInTransaction,
    required this.consumptions,
  });

  /// The persisted [CurrencyExchange] row.
  final CurrencyExchange exchange;

  /// The destination [CashLot] that received the transferred cost basis.
  /// Its [CashLot.sourceRefId] is patched to [exchange.id].
  final CashLot destinationLot;

  /// The [CashTransaction] row with type = [CashTransactionType.currencyExchangeOut].
  final CashTransaction exchangeOutTransaction;

  /// The [CashTransaction] row with type = [CashTransactionType.currencyExchangeIn].
  /// Its [CashTransaction.lotId] equals [destinationLot.id].
  final CashTransaction exchangeInTransaction;

  /// One [CashLotConsumption] per source lot drawn from (FIFO order).
  final List<CashLotConsumption> consumptions;
}
