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

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(CalmSnackBar.undoDuration);
    await tester.pump(const Duration(milliseconds: 300));
    expect(CalmSnackBar.isUndoSessionActive, isFalse);
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

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(CalmSnackBar.undoDuration);
    await tester.pump(const Duration(milliseconds: 300));
    expect(CalmSnackBar.isUndoSessionActive, isFalse);
  });

  testWidgets('CalmSnackBar.showMessage with undo auto-dismisses after undoDuration',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  CalmSnackBar.showMessage(
                    context,
                    message: 'Expense added',
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () {},
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Expense added'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.persist, isFalse);
    expect(snackBar.duration, CalmSnackBar.undoDuration);

    await tester.pump(const Duration(milliseconds: 300));

    await tester.pump(CalmSnackBar.undoDuration);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Expense added'), findsNothing);
    expect(find.text('Undo'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('CalmSnackBar.showUndo auto-dismisses after undoDuration', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Expense deleted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(CalmSnackBar.undoDuration);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Expense deleted'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(CalmSnackBar.isUndoSessionActive, isFalse);
  });
}
