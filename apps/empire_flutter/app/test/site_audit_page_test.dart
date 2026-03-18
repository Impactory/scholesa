import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/domain/models.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/modules/site/site_audit_page.dart';
import 'package:scholesa_app/services/export_service.dart';

String? _savedFileName;
String? _savedFileContent;

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-1-admin',
    'email': 'site-admin@scholesa.test',
    'displayName': 'Site Admin',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required AppState appState,
  required Widget child,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp(
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

  testWidgets('site audit loads site-scoped logs and exports a real file',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('auditLogs').doc('audit-1').set(
      <String, dynamic>{
        'actorId': 'site-admin-1',
        'actorRole': 'site',
        'action': 'pickup_authorization.saved',
        'entityType': 'pickupAuthorization',
        'entityId': 'pickup-1',
        'siteId': 'site-1',
        'details': <String, dynamic>{
          'learnerId': 'learner-1',
          'pickupCount': 2,
        },
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 18, 9, 30)),
      },
    );
    await firestore.collection('auditLogs').doc('audit-2').set(
      <String, dynamic>{
        'actorId': 'site-admin-2',
        'actorRole': 'site',
        'action': 'ignored.other.site',
        'entityType': 'other',
        'entityId': 'other-1',
        'siteId': 'site-2',
        'details': <String, dynamic>{},
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 18, 8, 0)),
      },
    );

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
        appState: _buildSiteState(),
        child: SiteAuditPage(
          auditLogLoader: AuditLogRepository(firestore: firestore).listBySite,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('pickup_authorization.saved'), findsOneWidget);
    expect(find.text('ignored.other.site'), findsNothing);
    expect(find.text('Entries'), findsOneWidget);

    await tester.tap(find.byTooltip('Export Audit Log'));
    await tester.pumpAndSettle();

    expect(find.text('Audit export downloaded.'), findsOneWidget);
    expect(_savedFileName, contains('site-audit-site-1-'));
    expect(_savedFileContent, contains('Site Audit Export'));
    expect(_savedFileContent, contains('pickup_authorization.saved'));
    expect(_savedFileContent, contains('learnerId: learner-1'));
  });

  testWidgets('site audit shows explicit error state when loading fails',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildSiteState(),
        child: SiteAuditPage(
          auditLogLoader: (String siteId) async {
            throw StateError('audit unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load audit logs right now'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
