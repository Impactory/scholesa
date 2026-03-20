import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/domain/models.dart';
import 'package:scholesa_app/modules/hq_admin/hq_exports_page.dart';
import 'package:scholesa_app/services/analytics_service.dart';
import 'package:scholesa_app/services/export_service.dart';

String? _savedFileName;
String? _savedFileContent;

AppState _buildHqState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'hq-1',
    'email': 'hq@scholesa.test',
    'displayName': 'HQ User',
    'role': 'hq',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({required Widget child, required AppState appState}) {
  return ChangeNotifierProvider<AppState>.value(
    value: appState,
    child: MaterialApp(
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
    ),
  );
}

void main() {
  setUp(() {
    _savedFileName = null;
    _savedFileContent = null;
    ExportService.instance.debugSaveTextFile = null;
  });

  testWidgets('hq exports downloads a real full bundle from live bundle data',
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

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildHqState(),
        child: HqExportsPage(
          analyticsLoader: () async => const TelemetryDashboardMetrics(
            weeklyAccountabilityAdherenceRate: 84.5,
            educatorReviewTurnaroundHoursAvg: 12.0,
            educatorReviewWithinSlaRate: 92.0,
            educatorReviewSlaHours: 48,
            interventionHelpedRate: 61.2,
            interventionTotal: 14,
            attendanceTrend: <AttendanceTrendPoint>[
              AttendanceTrendPoint(
                date: '2026-03-17',
                records: 12,
                events: 10,
                presentRate: 95.0,
              ),
              AttendanceTrendPoint(
                date: '2026-03-18',
                records: 13,
                events: 11,
                presentRate: 96.0,
              ),
            ],
          ),
          billingLoader: () async => <String, dynamic>{
            'invoices': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'INV-1', 'amount': 120.0},
            ],
            'payments': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'PAY-1', 'amount': 120.0},
            ],
            'subscriptions': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'SUB-1', 'amount': 49.0},
            ],
          },
          auditLoader: () async => <AuditLogModel>[
            AuditLogModel(
              id: 'audit-1',
              actorId: 'hq-1',
              actorRole: 'hq',
              action: 'export.downloaded',
              entityType: 'report',
              entityId: 'report-1',
              createdAt: Timestamp.fromDate(DateTime(2026, 3, 18, 10)),
            ),
          ],
          safetyLoader: () async => <String, dynamic>{
            'incidents': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'incident-1',
                'title': 'Minor playground incident',
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('HQ Exports'), findsOneWidget);
    expect(find.text('Analytics Bundle'), findsOneWidget);
    expect(find.text('Billing Bundle'), findsOneWidget);
    expect(find.text('Audit Bundle'), findsOneWidget);
    expect(find.text('Safety Bundle'), findsOneWidget);
    expect(find.text('Ready'), findsWidgets);

    await tester.tap(find.byTooltip('Download Full Bundle'));
    await tester.pumpAndSettle();

    expect(find.text('Full export bundle downloaded.'), findsOneWidget);
    expect(_savedFileName, contains('hq-export-full-'));
    expect(_savedFileContent, contains('HQ Full Export Bundle'));
    expect(_savedFileContent, contains('Intervention total: 14'));
    expect(_savedFileContent, contains('Invoices: 1'));
    expect(_savedFileContent, contains('Entries: 1'));
    expect(_savedFileContent, contains('Incidents: 1'));
  });

  testWidgets('hq exports shows partial unavailable state when one bundle fails',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildHqState(),
        child: HqExportsPage(
          analyticsLoader: () async {
            throw StateError('analytics unavailable');
          },
          billingLoader: () async => <String, dynamic>{
            'invoices': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'INV-1', 'amount': 120.0},
            ],
            'payments': const <Map<String, dynamic>>[],
            'subscriptions': const <Map<String, dynamic>>[],
          },
          auditLoader: () async => const <AuditLogModel>[],
          safetyLoader: () async => const <String, dynamic>{
            'incidents': <Map<String, dynamic>>[],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(
      find.text(
        'Some export bundles are unavailable right now. Ready bundles can still be downloaded.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Unable to load the analytics export bundle right now.'),
      findsOneWidget,
    );
  });

  testWidgets('hq exports copies full bundle when file export is unsupported',
      (WidgetTester tester) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          final Map<dynamic, dynamic> arguments = methodCall.arguments as Map<dynamic, dynamic>;
          clipboardText = arguments['text'] as String?;
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

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildHqState(),
        child: HqExportsPage(
          analyticsLoader: () async => const TelemetryDashboardMetrics(
            weeklyAccountabilityAdherenceRate: 84.5,
            educatorReviewTurnaroundHoursAvg: 12.0,
            educatorReviewWithinSlaRate: 92.0,
            educatorReviewSlaHours: 48,
            interventionHelpedRate: 61.2,
            interventionTotal: 14,
            attendanceTrend: <AttendanceTrendPoint>[
              AttendanceTrendPoint(
                date: '2026-03-17',
                records: 12,
                events: 10,
                presentRate: 95.0,
              ),
            ],
          ),
          billingLoader: () async => <String, dynamic>{
            'invoices': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'INV-1', 'amount': 120.0},
            ],
            'payments': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'PAY-1', 'amount': 120.0},
            ],
            'subscriptions': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'SUB-1', 'amount': 49.0},
            ],
          },
          auditLoader: () async => <AuditLogModel>[
            AuditLogModel(
              id: 'audit-1',
              actorId: 'hq-1',
              actorRole: 'hq',
              action: 'export.downloaded',
              entityType: 'report',
              entityId: 'report-1',
              createdAt: Timestamp.fromDate(DateTime(2026, 3, 18, 10)),
            ),
          ],
          safetyLoader: () async => <String, dynamic>{
            'incidents': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'incident-1',
                'title': 'Minor playground incident',
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Download Full Bundle'));
    await tester.pumpAndSettle();

    expect(find.text('Full export bundle copied to clipboard.'), findsOneWidget);
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('HQ Full Export Bundle'));
    expect(clipboardText, contains('Intervention total: 14'));
    expect(clipboardText, contains('Incidents: 1'));
  });
}
