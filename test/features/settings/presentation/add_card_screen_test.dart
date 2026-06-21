import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/settings/data/card_repository.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/settings/presentation/add_card_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('AddCardScreen tier visibility', () {
    testWidgets('shows tier selector when Mada is selected (English)', (tester) async {
      await tester.pumpWidget(_buildApp(locale: const Locale('en')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mada'));
      await tester.pumpAndSettle();

      expect(find.text('Card tier'), findsOneWidget);
      expect(find.text('Classic'), findsOneWidget);
      expect(find.text('Platinum'), findsOneWidget);
    });

    testWidgets('shows tier selector when Mada is selected (Arabic)', (tester) async {
      await tester.pumpWidget(_buildApp(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('مدى'));
      await tester.pumpAndSettle();

      expect(find.text('فئة البطاقة'), findsOneWidget);
      expect(find.text('كلاسيك'), findsOneWidget);
      expect(find.text('بلاتينيوم'), findsOneWidget);
    });

    testWidgets('Visa and MasterCard tier selectors remain visible', (tester) async {
      await tester.pumpWidget(_buildApp(locale: const Locale('en')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Visa'));
      await tester.pumpAndSettle();
      expect(find.text('Card tier'), findsOneWidget);

      await tester.tap(find.text('Mastercard'));
      await tester.pumpAndSettle();
      expect(find.text('Card tier'), findsOneWidget);
    });

    testWidgets('Mada can be saved after selecting tier', (tester) async {
      final repository = _RecordingCardRepository();

      await tester.pumpWidget(
        _buildApp(
          locale: const Locale('en'),
          cardRepository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mada'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Classic'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('D360'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '3666');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add card'));
      await tester.pumpAndSettle();

      expect(repository.addCalls, hasLength(1));
      expect(repository.addCalls.first.cardNetwork, 'Mada');
      expect(repository.addCalls.first.cardTier, 'Classic');
      expect(repository.addCalls.first.last4, '3666');
      expect(find.byType(AddCardScreen), findsNothing);
    });
  });
}

Widget _buildApp({
  Locale locale = const Locale('en'),
  CardRepository? cardRepository,
}) {
  return ProviderScope(
    overrides: [
      cardRepositoryProvider.overrideWithValue(
        cardRepository ?? _RecordingCardRepository(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AddCardScreen(),
    ),
  );
}

class _RecordingCardRepository extends CardRepository {
  _RecordingCardRepository() : super(AppDatabase());

  final List<_AddCardCall> addCalls = [];

  @override
  Future<List<CardProfile>> getAllCards() async => const [];

  @override
  Future<CardProfile> addCard({
    required String name,
    String? bankName,
    String? customBankName,
    String? cardNetwork,
    String? customCardNetwork,
    String? cardTier,
    String? customCardTier,
    String? last4,
    String? displayName,
  }) async {
    addCalls.add(
      _AddCardCall(
        name: name,
        bankName: bankName,
        cardNetwork: cardNetwork,
        cardTier: cardTier,
        last4: last4,
      ),
    );
    final now = DateTime.utc(2026, 1, 1);
    return CardProfile(
      id: addCalls.length,
      name: name,
      bankName: bankName,
      cardNetwork: cardNetwork,
      cardTier: cardTier,
      last4: last4,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _AddCardCall {
  const _AddCardCall({
    required this.name,
    this.bankName,
    this.cardNetwork,
    this.cardTier,
    this.last4,
  });

  final String name;
  final String? bankName;
  final String? cardNetwork;
  final String? cardTier;
  final String? last4;
}
