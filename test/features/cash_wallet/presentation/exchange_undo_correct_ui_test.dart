import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/currency_exchange_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/correct_currency_exchange_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_currency_exchange_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_result.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/exchange_correction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/exchange_correction_service.dart';
import 'package:travel_expenses/features/cash_wallet/domain/reverse_currency_exchange_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/cash_wallet/presentation/trip_cash_wallet_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final chinaTrip = Trip.create(
    id: 'trip-undo-china',
    name: 'Shanghai',
    destination: 'Shanghai',
    baseCurrency: 'CNY',
    destinationCurrency: 'CNY',
    homeCurrencySnapshot: 'SAR',
  );

  void sizeLarge(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  TripCashBalance balance(String code, double amount) => TripCashBalance(
        tripId: chinaTrip.id,
        currencyCode: code,
        balanceAmount: amount,
        updatedAt: DateTime.now().toUtc(),
      );

  CashTransaction exchangeInTx({String? exchangeId = 'exch-1'}) =>
      CashTransaction.create(
        id: 'in-1',
        tripId: chinaTrip.id,
        type: CashTransactionType.currencyExchangeIn,
        amount: 720,
        currencyCode: 'CNY',
        exchangeId: exchangeId,
        createdAt: DateTime.now().toUtc(),
      );

  Widget buildApp({
    required ExchangeCorrectionStatus status,
    _SpyReverseUseCase? reverse,
    _SpyCorrectUseCase? correct,
    Locale locale = const Locale('en'),
    List<CashTransaction>? transactions,
  }) {
    final repo = _FakeWalletRepository(
      balances: [balance('CNY', 720), balance('USD', 0)],
      transactions: transactions ?? [exchangeInTx()],
    );
    return ProviderScope(
      overrides: [
        cashWalletRepositoryProvider.overrideWithValue(repo),
        exchangeCorrectionServiceProvider
            .overrideWithValue(_FakeCorrectionService(status)),
        currencyExchangeRepositoryProvider
            .overrideWithValue(_FakeExchangeRepository()),
        if (reverse != null)
          reverseCurrencyExchangeUseCaseProvider.overrideWithValue(reverse),
        if (correct != null)
          correctCurrencyExchangeUseCaseProvider.overrideWithValue(correct),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripCashWalletScreen(trip: chinaTrip),
      ),
    );
  }

  ExchangeCorrectionStatus correctable() =>
      const ExchangeCorrectionStatus.correctable(
        exchangeId: 'exch-1',
        destinationLotId: 'lot-1',
      );

  ExchangeCorrectionStatus usedCash() => ExchangeCorrectionStatus.blocked(
        exchangeId: 'exch-1',
        reasonCode: ExchangeCorrectionReason.destinationCashUsed,
        destinationLotId: 'lot-1',
        affectedTransactions: [
          AffectedCashUse(
            type: AffectedCashUseType.cashExpense,
            amount: 100,
            currencyCode: 'CNY',
            date: DateTime(2026, 6, 20),
            title: 'Dumplings',
            referenceId: 'exp-1',
          ),
        ],
      );

  ExchangeCorrectionStatus usedCashWithCategory(String category) =>
      ExchangeCorrectionStatus.blocked(
        exchangeId: 'exch-1',
        reasonCode: ExchangeCorrectionReason.destinationCashUsed,
        destinationLotId: 'lot-1',
        affectedTransactions: [
          AffectedCashUse(
            type: AffectedCashUseType.cashExpense,
            amount: 250,
            currencyCode: 'CNY',
            date: DateTime(2026, 6, 20),
            title: category,
            referenceId: 'exp-2',
          ),
        ],
      );

  Future<void> openAffectedSheet(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    required ExchangeCorrectionStatus status,
  }) async {
    sizeLarge(tester);
    await tester.pumpWidget(buildApp(status: status, locale: locale));
    await tester.pumpAndSettle();

    final actionLabel = locale.languageCode == 'ar'
        ? 'عرض العمليات المتأثرة'
        : 'View affected transactions';
    await tester.tap(find.text(actionLabel));
    await tester.pumpAndSettle();
  }

  String sheetText(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .join('\n');
  }

  group('legacy exchange row actions', () {
    testWidgets(
        'null exchange_id hides Correct, Undo, and View affected transactions',
        (tester) async {
      sizeLarge(tester);
      await tester.pumpWidget(buildApp(
        status: correctable(),
        transactions: [exchangeInTx(exchangeId: null)],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Correct'), findsNothing);
      expect(find.text('Undo transaction'), findsNothing);
      expect(find.text('View affected transactions'), findsNothing);
    });
  });

  group('exchange row actions', () {
    testWidgets('correctable exchange shows Correct and Undo', (tester) async {
      sizeLarge(tester);
      await tester.pumpWidget(buildApp(status: correctable()));
      await tester.pumpAndSettle();

      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Undo transaction'), findsOneWidget);
      expect(find.text('View affected transactions'), findsNothing);
    });

    testWidgets('used-cash exchange shows only View affected transactions',
        (tester) async {
      sizeLarge(tester);
      await tester.pumpWidget(buildApp(status: usedCash()));
      await tester.pumpAndSettle();

      expect(find.text('View affected transactions'), findsOneWidget);
      expect(find.text('Correct'), findsNothing);
      expect(find.text('Undo transaction'), findsNothing);
    });

    testWidgets('View affected lists title, amount and currency',
        (tester) async {
      await openAffectedSheet(tester, status: usedCash());

      expect(find.text('Affected transactions'), findsOneWidget);
      expect(find.text('Dumplings'), findsOneWidget);
      expect(find.textContaining('100'), findsWidgets);
      expect(find.textContaining('CNY'), findsWidgets);
      expect(find.textContaining('Cash expense · Jun 20, 2026'), findsOneWidget);
    });
  });

  group('affected transactions sheet polish', () {
    testWidgets('Arabic blocking message has no duplicate wording',
        (tester) async {
      await openAffectedSheet(
        tester,
        locale: const Locale('ar'),
        status: usedCash(),
      );

      final text = sheetText(tester);
      expect(text, isNot(contains('لأن لأن')));
      expect(
        text,
        contains(
          'لا يمكن إلغاء هذه العملية الآن لأن النقد الناتج عنها استُخدم في عمليات لاحقة.',
        ),
      );
    });

    testWidgets('built-in category is localized in Arabic affected rows',
        (tester) async {
      await openAffectedSheet(
        tester,
        locale: const Locale('ar'),
        status: usedCashWithCategory('Accommodation'),
      );

      expect(find.text('إقامة'), findsOneWidget);
      expect(find.text('Accommodation'), findsNothing);
    });

    testWidgets('user-entered custom title is not translated in Arabic',
        (tester) async {
      await openAffectedSheet(
        tester,
        locale: const Locale('ar'),
        status: usedCash(),
      );

      expect(find.text('Dumplings'), findsOneWidget);
    });

    testWidgets('Arabic affected row uses locale-friendly date subtitle',
        (tester) async {
      await openAffectedSheet(
        tester,
        locale: const Locale('ar'),
        status: usedCashWithCategory('Accommodation'),
      );

      final text = sheetText(tester);
      expect(text, isNot(contains('Jun 2026 20')));
      expect(text, contains('20'));
      expect(text, contains('2026'));
      expect(text, contains('يونيو'));
      expect(text, contains('مصروف نقدي ·'));
    });
  });

  group('undo flow', () {
    testWidgets('Undo shows a confirmation before reversing', (tester) async {
      sizeLarge(tester);
      final reverse = _SpyReverseUseCase();
      await tester.pumpWidget(buildApp(status: correctable(), reverse: reverse));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Undo transaction'));
      await tester.pumpAndSettle();

      expect(find.text('Undo this exchange?'), findsOneWidget);
      // Not reversed yet — only the confirmation is shown.
      expect(reverse.calls, isEmpty);
    });

    testWidgets('confirming Undo calls the reverse use case', (tester) async {
      sizeLarge(tester);
      final reverse = _SpyReverseUseCase();
      await tester.pumpWidget(buildApp(status: correctable(), reverse: reverse));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Undo transaction'));
      await tester.pumpAndSettle();
      // The confirmation dialog repeats the "Undo transaction" label; tap it.
      await tester.tap(find.text('Undo transaction').last);
      await tester.pumpAndSettle();

      expect(reverse.calls, ['exch-1']);
    });
  });

  group('correct flow', () {
    testWidgets('Correct opens the sheet prefilled and does not reverse',
        (tester) async {
      sizeLarge(tester);
      final reverse = _SpyReverseUseCase();
      final correct = _SpyCorrectUseCase();
      await tester.pumpWidget(buildApp(
        status: correctable(),
        reverse: reverse,
        correct: correct,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Correct'));
      await tester.pumpAndSettle();

      expect(find.text('Correct Exchange'), findsOneWidget);
      // Prefilled with the original gave/received amounts.
      expect(find.text('100'), findsOneWidget);
      expect(find.text('720'), findsOneWidget);
      // Locked source currency shown as a chip.
      expect(find.text('USD'), findsWidgets);
      // Opening the sheet must NOT reverse or correct anything.
      expect(reverse.calls, isEmpty);
      expect(correct.calls, isEmpty);
    });

    testWidgets('Saving the correction calls the correct use case',
        (tester) async {
      sizeLarge(tester);
      final correct = _SpyCorrectUseCase();
      await tester.pumpWidget(buildApp(
        status: correctable(),
        correct: correct,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Correct'));
      await tester.pumpAndSettle();

      // Adjust the received amount and save.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '700');
      await tester.ensureVisible(find.text('Save correction'));
      await tester.tap(find.text('Save correction'));
      await tester.pumpAndSettle();

      expect(correct.calls, hasLength(1));
      expect(correct.calls.first.exchangeId, 'exch-1');
      expect(correct.calls.first.fromCurrency, 'USD');
      expect(correct.calls.first.fromAmount, 100);
      expect(correct.calls.first.toAmount, 700);
    });
  });

  group('localization', () {
    testWidgets('Arabic exchange action labels render', (tester) async {
      sizeLarge(tester);
      await tester.pumpWidget(
        buildApp(status: correctable(), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('تصحيح'), findsOneWidget);
      expect(find.text('إلغاء العملية'), findsOneWidget);
    });
  });
}

class _FakeWalletRepository extends CashWalletRepository {
  _FakeWalletRepository({
    required this.balances,
    required this.transactions,
  }) : super(AppDatabase());

  final List<TripCashBalance> balances;
  final List<CashTransaction> transactions;

  @override
  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async =>
      balances;

  @override
  Future<List<CashTransaction>> getRecentTransactionsByTrip(
    String tripId, {
    int limit = 20,
    bool includeReversed = false,
  }) async =>
      transactions;
}

class _FakeCorrectionService extends ExchangeCorrectionService {
  _FakeCorrectionService(this._status)
      : super(
          exchangeRepository: CurrencyExchangeRepository(AppDatabase()),
          lotRepository: CashLotRepository(AppDatabase()),
          consumptionRepository: CashLotConsumptionRepository(AppDatabase()),
        );

  final ExchangeCorrectionStatus _status;

  @override
  Future<ExchangeCorrectionStatus> getStatus(
    String exchangeId, {
    txn,
  }) async =>
      _status;
}

class _FakeExchangeRepository extends CurrencyExchangeRepository {
  _FakeExchangeRepository() : super(AppDatabase());

  @override
  Future<CurrencyExchange?> getExchangeById(String id, {txn}) async {
    return CurrencyExchange.create(
      id: id,
      tripId: 'trip-undo-china',
      fromCurrencyCode: 'USD',
      fromAmount: 100,
      toCurrencyCode: 'CNY',
      toAmount: 720,
      exchangeRate: 7.2,
      toLotId: 'lot-1',
    );
  }
}

class _SpyReverseUseCase extends ReverseCurrencyExchangeUseCase {
  _SpyReverseUseCase()
      : super(
          appDatabase: AppDatabase(),
          correctionService: _FakeCorrectionService(
            const ExchangeCorrectionStatus.correctable(
              exchangeId: 'exch-1',
              destinationLotId: 'lot-1',
            ),
          ),
          exchangeRepository: CurrencyExchangeRepository(AppDatabase()),
          lotRepository: CashLotRepository(AppDatabase()),
          consumptionRepository: CashLotConsumptionRepository(AppDatabase()),
          cashWalletRepository: CashWalletRepository(AppDatabase()),
        );

  final List<String> calls = [];

  @override
  Future<CurrencyExchange> execute(String exchangeId) async {
    calls.add(exchangeId);
    return CurrencyExchange.create(
      id: exchangeId,
      tripId: 'trip-undo-china',
      fromCurrencyCode: 'USD',
      fromAmount: 100,
      toCurrencyCode: 'CNY',
      toAmount: 720,
      exchangeRate: 7.2,
      toLotId: 'lot-1',
    );
  }
}

class _CorrectCall {
  const _CorrectCall(
      this.exchangeId, this.fromCurrency, this.fromAmount, this.toAmount);
  final String exchangeId;
  final String fromCurrency;
  final double fromAmount;
  final double toAmount;
}

class _SpyCorrectUseCase extends CorrectCurrencyExchangeUseCase {
  _SpyCorrectUseCase()
      : super(
          appDatabase: AppDatabase(),
          reverseUseCase: _SpyReverseUseCase(),
          recordUseCase: _ThrowingRecord(),
        );

  final List<_CorrectCall> calls = [];

  @override
  Future<CurrencyExchangeResult> execute({
    required String originalExchangeId,
    required String fromCurrencyCode,
    required double fromAmount,
    required String toCurrencyCode,
    required double toAmount,
    String? note,
    DateTime? createdAt,
  }) async {
    calls.add(_CorrectCall(
        originalExchangeId, fromCurrencyCode, fromAmount, toAmount));
    final lot = CashLot.create(
      id: 'new-lot',
      tripId: 'trip-undo-china',
      sourceType: 'exchange_in',
      sourceRefType: 'currency_exchange',
      sourceRefId: 'new-exch',
      currencyCode: toCurrencyCode,
      originalAmount: toAmount,
    );
    return CurrencyExchangeResult(
      exchange: CurrencyExchange.create(
        id: 'new-exch',
        tripId: 'trip-undo-china',
        fromCurrencyCode: fromCurrencyCode,
        fromAmount: fromAmount,
        toCurrencyCode: toCurrencyCode,
        toAmount: toAmount,
        exchangeRate: toAmount / fromAmount,
        toLotId: lot.id,
      ),
      destinationLot: lot,
      exchangeOutTransaction: CashTransaction.create(
        id: 'new-out',
        tripId: 'trip-undo-china',
        type: CashTransactionType.currencyExchangeOut,
        amount: fromAmount,
        currencyCode: fromCurrencyCode,
      ),
      exchangeInTransaction: CashTransaction.create(
        id: 'new-in',
        tripId: 'trip-undo-china',
        type: CashTransactionType.currencyExchangeIn,
        amount: toAmount,
        currencyCode: toCurrencyCode,
        lotId: lot.id,
      ),
      consumptions: const [],
    );
  }
}

class _ThrowingRecord extends RecordCurrencyExchangeUseCase {
  _ThrowingRecord()
      : super(
          appDatabase: AppDatabase(),
          exchangeEngine: CurrencyExchangeEngine(
            CashLotFifoEngine(CashLotRepository(AppDatabase())),
          ),
          cashWalletRepository: CashWalletRepository(AppDatabase()),
          lotRepository: CashLotRepository(AppDatabase()),
          consumptionRepository: CashLotConsumptionRepository(AppDatabase()),
          exchangeRepository: CurrencyExchangeRepository(AppDatabase()),
        );
}
