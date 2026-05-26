import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/design_system/calm_snackbar.dart';

void main() {
  testWidgets('CalmSnackBar replaces the current snackbar instead of stacking',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  CalmSnackBar.showMessage(context, message: 'First');
                  CalmSnackBar.showMessage(context, message: 'Second');
                },
                child: const Text('Show'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('CalmSnackBar.showUndo keeps undo action visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  unawaited(
                    CalmSnackBar.showUndo(
                      context,
                      message: 'Expense deleted',
                      undoLabel: 'Undo',
                      onUndo: () {},
                    ),
                  );
                },
                child: const Text('Delete'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Delete'));
    await tester.pump();

    expect(find.text('Expense deleted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('CalmSnackBar.showMessage skips while undo session is active',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      unawaited(
                        CalmSnackBar.showUndo(
                          context,
                          message: 'Expense deleted',
                          undoLabel: 'Undo',
                          onUndo: () {},
                        ),
                      );
                    },
                    child: const Text('Undo snack'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      CalmSnackBar.showMessage(context, message: 'Brief note');
                    },
                    child: const Text('Brief snack'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Undo snack'));
    await tester.pump();
    await tester.tap(find.text('Brief snack'));
    await tester.pump();

    expect(find.text('Expense deleted'), findsOneWidget);
    expect(find.text('Brief note'), findsNothing);
  });
}
