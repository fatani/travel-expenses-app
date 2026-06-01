import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/features/backup/presentation/backup_restore_screen.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/settings/presentation/cards_provider.dart';
import 'package:travel_expenses/features/settings/presentation/settings_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

class _EmptyCardsNotifier extends CardsNotifier {
  @override
  Future<List<CardProfile>> build() async => const [];
}

void main() {
  testWidgets('settings shows Backup & Restore entry with Create backup', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardsProvider.overrideWith(_EmptyCardsNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Backup & Restore'), findsOneWidget);
    expect(find.text('Save your data to a file'), findsOneWidget);
    expect(find.text('Restore from backup'), findsNothing);

    await tester.tap(find.text('Backup & Restore'));
    await tester.pumpAndSettle();

    expect(find.byType(BackupRestoreScreen), findsOneWidget);
    expect(find.text('Create backup'), findsOneWidget);
    expect(find.text('Restore from backup'), findsOneWidget);
    expect(
      find.text('Your data stays on this device.'),
      findsOneWidget,
    );
    expect(
      find.text('Create a backup file you can save elsewhere.'),
      findsOneWidget,
    );
    expect(
      find.text('CalmLedger does not sync to the cloud automatically.'),
      findsOneWidget,
    );
    expect(find.text('Replace all data'), findsNothing);
  });
}
