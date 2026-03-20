import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/hq_admin/hq_audit_page.dart';
import 'package:scholesa_app/modules/hq_admin/hq_billing_page.dart';
import 'package:scholesa_app/modules/hq_admin/hq_integrations_health_page.dart';
import 'package:scholesa_app/modules/hq_admin/hq_safety_page.dart';
import 'package:scholesa_app/services/export_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

String? _savedFileName;
String? _savedFileContent;
String? _clipboardText;

Widget _buildHarness({required Widget child, required AppState appState}) {
  return MultiProvider(
    providers: <ChangeNotifierProvider<dynamic>>[
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp(
      theme: ScholesaTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      home: child,
    ),
  );
}

AppState _buildAppState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'hq-1',
    'email': 'hq-1@scholesa.test',
    'displayName': 'HQ User',
    'role': 'hq',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

void main() {
  setUp(() {
    _savedFileName = null;
    _savedFileContent = null;
    _clipboardText = null;
    ExportService.instance.debugSaveTextFile = null;
  });

  testWidgets('HQ safety detail sheets remove the fake full report CTA',
      (WidgetTester tester) async {
    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      _savedFileName = fileName;
      _savedFileContent = content;
      return '/tmp/$fileName';
    };
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    await tester.pumpWidget(
      _buildHarness(
        child: HqSafetyPage(
          incidentsLoader: () async => <String, dynamic>{
            'incidents': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'incident-1',
                'title': 'Minor playground incident',
                'siteName': 'Site One',
                'severity': 'major',
                'updatedAt': '2026-03-17T10:00:00.000Z',
                'isEscalated': true,
              },
            ],
          },
        ),
        appState: _buildAppState(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    await tester.tap(find.text('Minor playground incident').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Download the current incident summary for offline review or escalation.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Download Incident Summary'));
    await tester.pumpAndSettle();

    expect(find.text('Incident summary downloaded.'), findsOneWidget);
    expect(_savedFileName, 'incident-summary-incident-1.txt');
    expect(_savedFileContent, isNotNull);
    expect(_savedFileContent, contains('Incident Summary'));
    expect(_savedFileContent, contains('ID: incident-1'));
    expect(_savedFileContent, contains('Title: Minor playground incident'));
    expect(_savedFileContent, contains('Site: Site One'));
    expect(_savedFileContent, contains('Severity: MAJOR'));
  });

  testWidgets('HQ safety copies incident summary when file export is unsupported',
      (WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          final Map<dynamic, dynamic> arguments =
              methodCall.arguments as Map<dynamic, dynamic>;
          _clipboardText = arguments['text'] as String?;
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

    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    await tester.pumpWidget(
      _buildHarness(
        child: HqSafetyPage(
          incidentsLoader: () async => <String, dynamic>{
            'incidents': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'incident-2',
                'title': 'Workshop injury review',
                'siteName': 'Site Two',
                'severity': 'critical',
                'updatedAt': '2026-03-18T10:00:00.000Z',
                'isEscalated': true,
              },
            ],
          },
        ),
        appState: _buildAppState(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workshop injury review').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download Incident Summary'));
    await tester.pumpAndSettle();

    expect(find.text('Incident summary copied to clipboard.'), findsOneWidget);
    expect(_clipboardText, isNotNull);
    expect(_clipboardText, contains('Incident Summary'));
    expect(_clipboardText, contains('ID: incident-2'));
    expect(_clipboardText, contains('Severity: CRITICAL'));
  });

  testWidgets(
      'HQ safety shows site unavailable when incident site identity is missing',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    await tester.pumpWidget(
      _buildHarness(
        child: HqSafetyPage(
          incidentsLoader: () async => <String, dynamic>{
            'incidents': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'incident-2',
                'title': 'Escort review',
                'severity': 'minor',
                'updatedAt': '2026-03-17T10:00:00.000Z',
              },
            ],
          },
        ),
        appState: _buildAppState(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.textContaining('Site unavailable'), findsOneWidget);
    expect(find.text('Unknown Site'), findsNothing);
  });

  testWidgets(
      'HQ integrations health shows site unavailable when site identity is missing',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    await tester.pumpWidget(
      _buildHarness(
        child: HqIntegrationsHealthPage(
          integrationsLoader: () async => <String, dynamic>{
            'syncJobs': <Map<String, dynamic>>[
              <String, dynamic>{
                'siteId': 'site-unknown',
                'provider': 'github',
                'status': 'healthy',
                'updatedAt': '2026-03-17T10:00:00.000Z',
              },
            ],
            'connections': const <Map<String, dynamic>>[],
          },
        ),
        appState: _buildAppState(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('site-unknown'), findsOneWidget);
    expect(find.text('Unknown Site'), findsNothing);
  });

  testWidgets('HQ billing invoice cards remove the fake send invoice CTA',
      (WidgetTester tester) async {
    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      _savedFileName = fileName;
      _savedFileContent = content;
      return '/tmp/$fileName';
    };
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    await tester.pumpWidget(
      _buildHarness(
        child: HqBillingPage(
          billingLoader: () async => <String, dynamic>{
            'siteOptions': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'all', 'label': 'All Sites'},
            ],
            'invoices': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'INV-1001',
                'parent': 'Parent One',
                'learner': 'Learner One',
                'site': 'Site One',
                'amount': 120.0,
                'status': 'pending',
                'date': '2026-03-17T10:00:00.000Z',
              },
            ],
            'payments': <Map<String, dynamic>>[],
            'subscriptions': <Map<String, dynamic>>[],
          },
        ),
        appState: _buildAppState(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('INV-1001'), findsOneWidget);
    expect(find.text('Invoice sending is not available in the app yet.'),
        findsNothing);

    final Finder sendReminderButton =
        find.byTooltip('Download Invoice Reminder');
    await tester.ensureVisible(sendReminderButton);
    await tester.tap(sendReminderButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Invoice reminder downloaded.'), findsOneWidget);
    expect(_savedFileName, 'invoice-reminder-INV-1001.txt');
    expect(_savedFileContent, isNotNull);
    expect(_savedFileContent, contains('Invoice Reminder'));
    expect(_savedFileContent, contains('ID: INV-1001'));
    expect(_savedFileContent, contains('Parent: Parent One'));
    expect(_savedFileContent, contains('Learner: Learner One'));

    final Finder viewInvoiceButton = find.byIcon(Icons.visibility);
    await tester.ensureVisible(viewInvoiceButton);
    await tester.tap(viewInvoiceButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Invoice INV-1001'), findsOneWidget);
  });

  testWidgets('HQ billing export downloads live financial data',
      (WidgetTester tester) async {
    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      _savedFileName = fileName;
      _savedFileContent = content;
      return '/tmp/$fileName';
    };
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    await tester.pumpWidget(
      _buildHarness(
        child: HqBillingPage(
          billingLoader: () async => <String, dynamic>{
            'siteOptions': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'all', 'label': 'All Sites'},
            ],
            'invoices': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'INV-3001',
                'parent': 'Parent Export',
                'learner': 'Learner Export',
                'site': 'Site One',
                'amount': 95.0,
                'status': 'pending',
                'date': '2026-03-17T10:00:00.000Z',
              },
            ],
            'payments': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'PAY-3001',
                'source': 'Card ending 4242',
                'site': 'Site One',
                'amount': 95.0,
                'status': 'completed',
                'date': '2026-03-17T10:00:00.000Z',
              },
            ],
            'subscriptions': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'SUB-3001',
                'owner': 'Parent Export',
                'site': 'Site One',
                'plan': 'Studio Core',
                'amount': 95.0,
                'status': 'active',
              },
            ],
          },
        ),
        appState: _buildAppState(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();

    expect(find.text('Export Financials'), findsNothing);
    expect(find.text('Financial export downloaded.'), findsOneWidget);
    expect(_savedFileName, contains('hq-financials'));
    expect(_savedFileContent, isNotNull);
    expect(_savedFileContent, contains('Export Financials'));
    expect(_savedFileContent, contains('INV-3001'));
    expect(_savedFileContent, contains('PAY-3001'));
    expect(_savedFileContent, contains('SUB-3001'));
  });

  testWidgets(
      'HQ billing shows precise unavailable labels for missing identity fields',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    await tester.pumpWidget(
      _buildHarness(
        child: HqBillingPage(
          billingLoader: () async => <String, dynamic>{
            'siteOptions': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'all', 'label': 'All Sites'},
            ],
            'invoices': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'INV-2001',
                'amount': 85.0,
                'status': 'pending',
                'date': '2026-03-17T10:00:00.000Z',
              },
            ],
            'payments': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'PAY-1',
                'amount': 85.0,
                'date': '2026-03-17T10:00:00.000Z',
              },
            ],
            'subscriptions': <Map<String, dynamic>>[
              <String, dynamic>{
                'learners': 1,
                'amount': 85.0,
                'status': 'active',
              },
            ],
          },
        ),
        appState: _buildAppState(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Parent unavailable'), findsOneWidget);
    expect(find.textContaining('Learner unavailable'), findsOneWidget);
    expect(find.textContaining('Site unavailable'), findsOneWidget);

    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    expect(find.text('Payment source unavailable'), findsOneWidget);

    await tester.tap(find.text('Subscriptions'));
    await tester.pumpAndSettle();
    expect(find.text('Subscription owner unavailable'), findsOneWidget);
  });

  testWidgets('HQ billing empty tabs use section-specific empty states',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    await tester.pumpWidget(
      _buildHarness(
        child: HqBillingPage(
          billingLoader: () async => <String, dynamic>{
            'siteOptions': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'all', 'label': 'All Sites'},
            ],
            'invoices': <Map<String, dynamic>>[],
            'payments': <Map<String, dynamic>>[],
            'subscriptions': <Map<String, dynamic>>[],
          },
        ),
        appState: _buildAppState(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No invoices found'), findsOneWidget);
    expect(find.text('No records found'), findsNothing);

    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    expect(find.text('No payments found'), findsOneWidget);

    await tester.tap(find.text('Subscriptions'));
    await tester.pumpAndSettle();
    expect(find.text('No subscriptions found'), findsOneWidget);
  });

  testWidgets('HQ audit export action shows an honest empty-export message',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    await tester.pumpWidget(
      _buildHarness(
        child: const HqAuditPage(),
        appState: _buildAppState(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.download_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Export Audit Logs'), findsNothing);
    expect(find.text('No audit records to export yet.'), findsOneWidget);
    expect(find.textContaining('Audit log exports are not available'),
        findsNothing);
  });
}
