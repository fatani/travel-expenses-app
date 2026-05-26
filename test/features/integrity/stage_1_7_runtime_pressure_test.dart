import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/design_system/calm_snackbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Stage 1.7 runtime pressure', () {
    test('AppDatabase.database shares one open across parallel callers', () async {
      final appDatabase = AppDatabase(
        databaseFileName:
            'stage_1_7_parallel_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      addTearDown(appDatabase.close);

      final results = await Future.wait([
        appDatabase.database,
        appDatabase.database,
        appDatabase.database,
        appDatabase.database,
        appDatabase.database,
      ]);

      expect(results.map((db) => db.path).toSet(), hasLength(1));
    });

    testWidgets('CalmSnackBar.showMessage is a no-op after route disposal',
        (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: Text('Home'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(capturedContext.mounted, isFalse);
      CalmSnackBar.showMessage(capturedContext, message: 'After dispose');
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
