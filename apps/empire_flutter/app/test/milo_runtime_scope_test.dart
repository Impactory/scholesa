import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';
import 'package:scholesa_app/runtime/milo_runtime_scope.dart';

void main() {
  group('MiloRuntimeScope', () {
    testWidgets('renders child without AppState in tree', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MiloRuntimeScope(child: Text('hello')),
        ),
      );
      // _initializeRuntime catches the ProviderNotFoundException and degrades.
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('renders child when AppState has no userId', (
      WidgetTester tester,
    ) async {
      final AppState appState = AppState(); // all fields null by default
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: const MiloRuntimeScope(child: Text('empty state')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('empty state'), findsOneWidget);
    });

    testWidgets('renders child when AppState has userId but no siteId', (
      WidgetTester tester,
    ) async {
      final AppState appState = AppState();
      // Set userId and role but no siteIds — _initializeRuntime early-returns.
      appState.updateFromMeResponse(<String, dynamic>{
        'userId': 'u1',
        'role': 'learner',
        // no activeSiteId, empty siteIds
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: const MiloRuntimeScope(child: Text('no site')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('no site'), findsOneWidget);
    });

    testWidgets(
      'no LearningRuntimeProvider in tree when AppState is missing',
      (WidgetTester tester) async {
        LearningRuntimeProvider? captured;
        await tester.pumpWidget(
          MaterialApp(
            home: MiloRuntimeScope(
              child: Builder(
                builder: (BuildContext context) {
                  // read as nullable — should be null because runtime was
                  // never initialized (no AppState).
                  captured = context.read<LearningRuntimeProvider?>();
                  return const Text('probe');
                },
              ),
            ),
          ),
        );
        expect(find.text('probe'), findsOneWidget);
        expect(captured, isNull);
      },
    );

    testWidgets(
      'no LearningRuntimeProvider when AppState has incomplete session info',
      (WidgetTester tester) async {
        final AppState appState = AppState(); // empty
        LearningRuntimeProvider? captured;
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AppState>.value(
              value: appState,
              child: MiloRuntimeScope(
                child: Builder(
                  builder: (BuildContext context) {
                    captured = context.read<LearningRuntimeProvider?>();
                    return const Text('probe2');
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('probe2'), findsOneWidget);
        expect(captured, isNull);
      },
    );

    testWidgets('does not crash on dispose without AppState', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MiloRuntimeScope(child: Text('disposable')),
        ),
      );
      expect(find.text('disposable'), findsOneWidget);

      // Replace the widget tree to trigger dispose of MiloRuntimeScope.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      // No exception means dispose handled gracefully.
      expect(find.text('disposable'), findsNothing);
    });

    testWidgets('does not crash on dispose with empty AppState', (
      WidgetTester tester,
    ) async {
      final AppState appState = AppState();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: const MiloRuntimeScope(child: Text('disposable2')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('disposable2'), findsOneWidget);

      // Tear down the tree.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(find.text('disposable2'), findsNothing);
    });
  });
}
