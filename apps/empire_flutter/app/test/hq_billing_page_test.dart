import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/hq_admin/hq_billing_page.dart';
import 'package:scholesa_app/services/export_service.dart';

Finder _dropdownField(String hintText) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.decoration.hintText == hintText,
  );
}

Widget _buildHarness(Widget child, {AppState? appState}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(
        value: appState ?? _buildAppState(),
      ),
    ],
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

AppState _buildAppState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'hq-user-1',
    'email': 'hq-user-1@scholesa.test',
    'displayName': 'HQ Admin',
    'role': 'hq',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <dynamic>[],
  });
  return state;
}

void main() {
  setUp(() {
    ExportService.instance.debugSaveTextFile = null;
  });

  testWidgets(
      'HQ billing shows a real load error instead of empty finance tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        HqBillingPage(
          billingLoader: () async {
            throw StateError('billing backend unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.text('Billing data is temporarily unavailable'), findsOneWidget);
    expect(
      find.text(
          'We could not load billing records. Retry to check the current state.'),
      findsWidgets,
    );
    expect(find.text('No invoices found'), findsNothing);
    expect(find.text('No payments found'), findsNothing);
    expect(find.text('No subscriptions found'), findsNothing);
    expect(find.text('Retry'), findsWidgets);
  });

  testWidgets('HQ billing creates invoices from the sheet with live form data',
      (WidgetTester tester) async {
    final List<Map<String, dynamic>> createdInvoices = <Map<String, dynamic>>[];

    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    await tester.pumpWidget(
      _buildHarness(
        HqBillingPage(
          billingLoader: () async => <String, dynamic>{
            'siteOptions': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'all', 'label': 'All Sites'},
            ],
            'invoices': <Map<String, dynamic>>[],
            'payments': <Map<String, dynamic>>[],
            'subscriptions': <Map<String, dynamic>>[],
          },
          userOptionsLoader: (String? siteId) async =>
              <String, List<Map<String, dynamic>>>{
            'parents': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'parent-1', 'displayName': 'Parent One'},
            ],
            'learners': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'learner-1',
                'displayName': 'Learner One'
              },
            ],
          },
          invoiceCreator: (Map<String, dynamic> payload) async {
            createdInvoices.add(payload);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Invoice'));
    await tester.pumpAndSettle();

    final Finder sheetScrollable = find.byType(Scrollable).last;
    final Finder parentField = _dropdownField('Select parent');
    final Finder learnerField = _dropdownField('Select learner');

    await tester.ensureVisible(parentField);
    await tester.tap(parentField, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parent One').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(learnerField);
    await tester.tap(learnerField, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learner One').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '120');
    await tester.enterText(
        find.byType(TextField).at(1), 'Studio tuition for March');
    await tester.scrollUntilVisible(
      find.text('Create Invoice').last,
      250,
      scrollable: sheetScrollable,
    );
    await tester.tap(find.text('Create Invoice').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Invoice created successfully'), findsOneWidget);
    expect(createdInvoices, hasLength(1));
    expect(createdInvoices.single['parentId'], 'parent-1');
    expect(createdInvoices.single['learnerId'], 'learner-1');
    expect(createdInvoices.single['amount'], 120.0);
    expect(createdInvoices.single['description'], 'Studio tuition for March');
    expect(createdInvoices.single['siteId'], 'site-1');
  });

  testWidgets('HQ billing fails closed when invoice creation fails',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    await tester.pumpWidget(
      _buildHarness(
        HqBillingPage(
          billingLoader: () async => <String, dynamic>{
            'siteOptions': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'all', 'label': 'All Sites'},
            ],
            'invoices': <Map<String, dynamic>>[],
            'payments': <Map<String, dynamic>>[],
            'subscriptions': <Map<String, dynamic>>[],
          },
          userOptionsLoader: (String? siteId) async =>
              <String, List<Map<String, dynamic>>>{
            'parents': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'parent-1', 'displayName': 'Parent One'},
            ],
            'learners': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'learner-1',
                'displayName': 'Learner One'
              },
            ],
          },
          invoiceCreator: (Map<String, dynamic> payload) async {
            throw Exception('invoice callable unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Invoice'));
    await tester.pumpAndSettle();

    final Finder sheetScrollable = find.byType(Scrollable).last;
    final Finder parentField = _dropdownField('Select parent');
    final Finder learnerField = _dropdownField('Select learner');

    await tester.ensureVisible(parentField);
    await tester.tap(parentField, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parent One').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(learnerField);
    await tester.tap(learnerField, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learner One').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '120');
    await tester.enterText(
        find.byType(TextField).at(1), 'Studio tuition for March');
    await tester.scrollUntilVisible(
      find.text('Create Invoice').last,
      250,
      scrollable: sheetScrollable,
    );
    await tester.tap(find.text('Create Invoice').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Invoice creation failed'), findsOneWidget);
  });

  testWidgets('HQ billing copies financial export when file export is unsupported',
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

    await tester.pumpWidget(
      _buildHarness(
        HqBillingPage(
          billingLoader: () async => <String, dynamic>{
            'siteOptions': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'all', 'label': 'All Sites'},
            ],
            'invoices': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'INV-100',
                'parent': 'Parent One',
                'learner': 'Learner One',
                'site': 'Harbor Studio',
                'date': '2026-03-20',
                'amount': 120.0,
                'status': 'paid',
              },
            ],
            'payments': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'PAY-1', 'amount': 120.0},
            ],
            'subscriptions': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'SUB-1', 'amount': 49.0},
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download).first);
    await tester.pumpAndSettle();

    expect(find.text('Financial export copied to clipboard.'), findsOneWidget);
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('Export Financials'));
    expect(clipboardText, contains('Harbor Studio'));
  });

  testWidgets('HQ billing copies invoice reminder when file export is unsupported',
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

    await tester.pumpWidget(
      _buildHarness(
        HqBillingPage(
          billingLoader: () async => <String, dynamic>{
            'siteOptions': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'all', 'label': 'All Sites'},
            ],
            'invoices': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'INV-200',
                'parent': 'Parent One',
                'learner': 'Learner One',
                'site': 'Harbor Studio',
                'date': '2026-03-20',
                'amount': 120.0,
                'status': 'overdue',
              },
            ],
            'payments': <Map<String, dynamic>>[],
            'subscriptions': <Map<String, dynamic>>[],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Download Invoice Reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Invoice reminder copied to clipboard.'), findsOneWidget);
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('Invoice Reminder'));
    expect(clipboardText, contains('INV-200'));
  });
}
