import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/modules/hq_admin/hq_approvals_page.dart';

Widget _buildHarness(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
    ),
    locale: const Locale('en'),
    supportedLocales: const <Locale>[
      Locale('en'),
      Locale('zh', 'CN'),
      Locale('zh', 'TW'),
    ],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  testWidgets('HQ approvals shows a real load error instead of a fake empty queue',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        HqApprovalsPage(
          loadApprovals: () async {
            throw StateError('approvals backend unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Approvals are temporarily unavailable'), findsOneWidget);
    expect(
      find.text('We could not load the approvals queue. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('No pending approvals'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
      'HQ approvals keeps an item pending when the approval action fails',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        HqApprovalsPage(
          loadApprovals: () async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'approval-1',
              'title': 'Studio Launch Agreement',
              'submittedBy': 'Ops',
              'status': 'pending',
              'sourceCollection': 'partnerContracts',
              'updatedAt': DateTime(2026, 3, 20, 9).toIso8601String(),
            },
          ],
          decideApproval: ({required String id, required String status}) async {
            throw StateError('decision failed');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Studio Launch Agreement'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to update this approval right now.'),
      findsOneWidget,
    );
    expect(find.text('Approved: Studio Launch Agreement'), findsNothing);
    expect(find.text('Studio Launch Agreement'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
  });

  testWidgets(
      'HQ approvals moves a decided item into completed even if the refresh fails',
      (WidgetTester tester) async {
    int loadCalls = 0;

    await tester.pumpWidget(
      _buildHarness(
        HqApprovalsPage(
          loadApprovals: () async {
            loadCalls += 1;
            if (loadCalls == 1) {
              return <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'approval-1',
                  'title': 'Studio Launch Agreement',
                  'submittedBy': 'Ops',
                  'status': 'pending',
                  'sourceCollection': 'partnerContracts',
                  'updatedAt': DateTime(2026, 3, 20, 9).toIso8601String(),
                },
              ];
            }
            throw StateError('refresh failed');
          },
          decideApproval: ({required String id, required String status}) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Approved: Studio Launch Agreement'), findsOneWidget);
    expect(find.text('Studio Launch Agreement'), findsNothing);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(find.text('Studio Launch Agreement'), findsOneWidget);
    expect(
      find.text(
        'Unable to refresh approvals right now. Showing the last successful data.',
      ),
      findsOneWidget,
    );
  });
}