import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../data/cash_lot_repository.dart';
import '../data/cash_wallet_repository.dart';
import 'atm_withdrawal_result.dart';
import 'cash_lot.dart';

/// Use case that records an ATM cash withdrawal atomically:
///
/// 1. Validates inputs.
/// 2. Opens one SQLite transaction containing:
///    a. Insert [cash_lots] row (source_type = 'atm_withdrawal').
///    b. Insert [cash_transactions] row (type = 'atm_withdrawal',
///       lot_id = [CashLot.id]).
///    c. Update [trip_cash_balances] by +[receivedAmount].
///    d. If [feeAmount] > 0: insert a card [expenses] row for the ATM fee.
///
/// ## Cost-basis rule
///
/// ```
/// cashPortionAmount = chargedAmount - (feeAmount ?? 0)
/// lot.homeCurrencyAmount = cashPortionAmount
/// lot.effectiveRate      = cashPortionAmount / receivedAmount
/// ```
///
/// If [chargedAmount] is `null` → lot has no cost basis (both fields null).
///
/// The ATM fee is **excluded** from the lot's cost basis: it is recorded as a
/// separate card expense and does not affect [trip_cash_balances].
///
/// ## Fee card expense
///
/// Created only when `feeAmount != null && feeAmount > 0`:
/// * payment_method  = 'Credit Card'
/// * payment_channel = 'ATM Withdrawal Fee'
/// * category        = 'Fees'
/// * card_profile_id = [fundingCardId]
///
/// ## Atomicity
///
/// If any step fails the entire transaction rolls back — no partial lot, no
/// partial cash_transaction, no partial balance update, no partial fee expense.
class RecordAtmWithdrawalUseCase {
  RecordAtmWithdrawalUseCase({
    required AppDatabase appDatabase,
    required CashWalletRepository cashWalletRepository,
    required CashLotRepository lotRepository,
    required ExpenseRepository expenseRepository,
    Uuid? uuid,
  })  : _appDatabase = appDatabase,
        _cashWalletRepository = cashWalletRepository,
        _lotRepository = lotRepository,
        _expenseRepository = expenseRepository,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final CashWalletRepository _cashWalletRepository;
  final CashLotRepository _lotRepository;
  final ExpenseRepository _expenseRepository;
  final Uuid _uuid;

  /// Records an ATM withdrawal.
  ///
  /// [receivedAmount]  — the cash handed to you (always > 0).
  /// [receivedCurrency] — ISO-4217 code of the received cash (e.g. 'JPY').
  /// [chargedAmount]   — what was debited from your funding account (optional).
  /// [chargedCurrency] — currency of the charge; required when [chargedAmount]
  ///                     is provided.
  /// [feeAmount]       — separate ATM fee; must be < [chargedAmount] when both
  ///                     are provided; must be ≥ 0.
  /// [feeCurrency]     — currency of the fee (defaults to [chargedCurrency]).
  /// [feeNote]         — title for the fee expense (defaults to 'ATM Fee').
  /// [fundingCardId]   — card profile ID for the fee expense.
  /// [note]            — free-text note for the cash transaction.
  /// [createdAt]       — timestamp; defaults to now.
  Future<AtmWithdrawalResult> execute({
    required String tripId,
    required double receivedAmount,
    required String receivedCurrency,
    double? chargedAmount,
    String? chargedCurrency,
    double? feeAmount,
    String? feeCurrency,
    String? feeNote,
    int? fundingCardId,
    String? note,
    DateTime? createdAt,
  }) async {
    // ── Validation ───────────────────────────────────────────────────────────
    if (receivedAmount <= 0) {
      throw ArgumentError.value(
          receivedAmount, 'receivedAmount', 'Must be > 0');
    }
    if (receivedCurrency.trim().isEmpty) {
      throw ArgumentError.value(
          receivedCurrency, 'receivedCurrency', 'Must not be empty');
    }
    if (chargedAmount != null && chargedAmount <= 0) {
      throw ArgumentError.value(
          chargedAmount, 'chargedAmount', 'Must be > 0 when provided');
    }
    if (feeAmount != null && feeAmount < 0) {
      throw ArgumentError.value(feeAmount, 'feeAmount', 'Must be ≥ 0');
    }
    if (feeAmount != null &&
        feeAmount > 0 &&
        chargedAmount != null &&
        feeAmount >= chargedAmount) {
      throw ArgumentError(
          'feeAmount ($feeAmount) must be less than chargedAmount ($chargedAmount)');
    }

    // ── Cost-basis derivation ─────────────────────────────────────────────────
    final effectiveFee = feeAmount ?? 0.0;
    final double? cashPortionAmount =
        chargedAmount != null ? chargedAmount - effectiveFee : null;
    final String? normalizedChargedCurrency =
        chargedCurrency?.trim().toUpperCase();
    final double? effectiveRate =
        (cashPortionAmount != null && receivedAmount > 0)
            ? cashPortionAmount / receivedAmount
            : null;

    final lotId = _uuid.v4();
    final normalizedReceived = receivedCurrency.trim().toUpperCase();
    final timestamp = (createdAt ?? DateTime.now()).toUtc();

    // ── Build the Cash Lot (no DB write yet) ──────────────────────────────────
    final lot = CashLot.create(
      id: lotId,
      tripId: tripId,
      sourceType: 'atm_withdrawal',
      sourceRefType: 'cash_transaction', // filled in after txn insert
      sourceRefId: '',                   // placeholder — patched below
      currencyCode: normalizedReceived,
      originalAmount: receivedAmount,
      remainingAmount: receivedAmount,
      homeCurrencyAmount: cashPortionAmount,
      homeCurrencyCode: normalizedChargedCurrency,
      effectiveRate: effectiveRate,
      createdAt: timestamp,
      note: note,
    );

    // ── Fee expense (built but not written yet) ───────────────────────────────
    final hasFee = feeAmount != null && feeAmount > 0;
    final effectiveFeeCurrency = (feeCurrency?.trim().isNotEmpty == true
            ? feeCurrency!.trim().toUpperCase()
            : null) ??
        normalizedChargedCurrency ??
        normalizedReceived;

    Expense? feeExpense;
    if (hasFee) {
      // feeAmount is promoted non-null by hasFee guard
      final effectiveFeeAmount = feeAmount;
      feeExpense = Expense.create(
        tripId: tripId,
        title: (feeNote != null && feeNote.trim().isNotEmpty)
            ? feeNote.trim()
            : 'ATM Fee',
        amount: effectiveFeeAmount,
        currencyCode: effectiveFeeCurrency,
        transactionAmount: effectiveFeeAmount,
        transactionCurrency: effectiveFeeCurrency,
        paymentMethod: 'Credit Card',
        paymentChannel: 'ATM Withdrawal Fee',
        category: 'Fees',
        cardProfileId: fundingCardId,
        spentAt: timestamp,
      );
    }

    // ── Atomic transaction ────────────────────────────────────────────────────
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      // a. Insert lot
      final insertedLot = await _lotRepository.insertCashLot(lot, txn: txn);

      // b & c. Insert cash_transaction with lot_id + update balance
      final cashTx = await _cashWalletRepository.recordAtmInflow(
        txn: txn,
        tripId: tripId,
        lotId: insertedLot.id,
        amount: receivedAmount,
        currencyCode: normalizedReceived,
        homeCurrencyAmount: cashPortionAmount,
        homeCurrencyCode: normalizedChargedCurrency,
        note: note,
        createdAt: timestamp,
      );

      // Patch lot's sourceRefId to point to the cash_transaction.id.
      // We do this via a targeted UPDATE so the lot row reflects the real ref.
      await _lotRepository.updateLotSourceRef(
        lotId: insertedLot.id,
        sourceRefId: cashTx.id,
        txn: txn,
      );

      // d. Optional fee card expense
      Expense? createdFee;
      if (feeExpense != null) {
        createdFee =
            await _expenseRepository.createExpense(feeExpense, txn: txn);
      }

      return AtmWithdrawalResult(
        cashLot: insertedLot.copyWith(sourceRefId: cashTx.id),
        cashTransaction: cashTx,
        feeExpense: createdFee,
      );
    });
  }
}
