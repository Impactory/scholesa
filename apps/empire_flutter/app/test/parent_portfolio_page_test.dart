import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/parent/parent_models.dart';
import 'package:scholesa_app/modules/parent/parent_portfolio_page.dart';
import 'package:scholesa_app/modules/parent/parent_service.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';

class _StubParentService extends ChangeNotifier implements ParentService {
  _StubParentService({
    required this.parentId,
    required this.learnerSummaries,
    this.error,
  });

  @override
  final String parentId;

  @override
  final List<LearnerSummary> learnerSummaries;

  @override
  final String? error;

  @override
  final bool isLoading = false;

  @override
  final BillingSummary? billingSummary = null;

  int loadCallCount = 0;

  @override
  Future<void> loadParentData() async {
    loadCallCount += 1;
    notifyListeners();
  }
}

AppState _buildParentState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'parent-test-1',
    'email': 'parent@scholesa.test',
    'displayName': 'Parent One',
    'role': 'parent',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': const <dynamic>[],
  });
  return state;
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required ParentService parentService,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(value: _buildParentState()),
        ChangeNotifierProvider<ParentService>.value(value: parentService),
        Provider<LearningRuntimeProvider?>.value(value: null),
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
        home: const ParentPortfolioPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'parent portfolio page shows explicit load error instead of fake empty portfolio copy',
      (WidgetTester tester) async {
    final _StubParentService service = _StubParentService(
      parentId: 'parent-test-1',
      learnerSummaries: const <LearnerSummary>[],
      error: 'Failed to load data: portfolio unavailable',
    );

    await _pumpPage(
      tester,
      parentService: service,
    );

    expect(find.text('Unable to load portfolio right now'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No items yet'), findsNothing);
    final int loadCallCountAfterMount = service.loadCallCount;

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(service.loadCallCount, loadCallCountAfterMount + 1);
  });
}
