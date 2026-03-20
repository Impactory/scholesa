import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/modules/hq_admin/hq_audit_page.dart';
import 'package:scholesa_app/services/export_service.dart';

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
  setUp(() {
    ExportService.instance.debugSaveTextFile = null;
  });

  testWidgets('HQ audit shows a real load error instead of empty audit sections',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        HqAuditPage(
          auditLogsLoader: () async {
            throw StateError('audit backend unavailable');
          },
          redTeamReviewsLoader: () async => <Map<String, dynamic>>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Audit data is temporarily unavailable'), findsOneWidget);
    expect(
      find.text('We could not load audit records. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('No audit logs found'), findsNothing);
    expect(find.text('No red team reviews yet'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('HQ audit copies export when file export is unsupported',
      (WidgetTester tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          final Object? args = methodCall.arguments;
          if (args is Map) {
            copiedText = args['text'] as String?;
          }
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      throw UnsupportedError('File export is not supported on this platform.');
    };

    await tester.pumpWidget(
      _buildHarness(
        HqAuditPage(
          auditLogsLoader: () async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'audit-1',
              'action': 'policy.updated',
              'category': 'admin',
              'actor': 'HQ Admin',
              'details': 'Updated export rules',
              'createdAt': '2026-03-18T09:30:00.000Z',
            },
          ],
          redTeamReviewsLoader: () async => <Map<String, dynamic>>[
            <String, dynamic>{
              'title': 'Vendor review',
              'decision': 'continue',
              'partnerStatus': 'active',
              'recommendations': 'Keep monitoring',
              'nextAction': 'Check quarterly',
              'updatedAt': '2026-03-18T10:00:00.000Z',
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Audit export copied to clipboard.'), findsOneWidget);
    expect(copiedText, contains('Export Audit Logs'));
    expect(copiedText, contains('Policy Updated'));
    expect(copiedText, contains('Vendor review'));
  });
}