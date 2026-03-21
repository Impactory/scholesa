import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/site/site_marketplace_panel.dart';

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-user-1',
    'email': 'site-user-1@scholesa.test',
    'displayName': 'Site Lead',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness(Widget child) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
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
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'site marketplace shows explicit unavailable state on first-load failure',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        SiteMarketplacePanel(
          marketplaceSnapshotLoader: ({
            required String siteId,
            required String userId,
          }) async {
            throw StateError('marketplace unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load marketplace data right now'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No published marketplace offerings are available yet.'),
        findsNothing);
    expect(find.text('No paid orders yet'), findsNothing);
  });

  testWidgets('site marketplace keeps stale data visible after refresh failure',
      (WidgetTester tester) async {
    int loadCount = 0;

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        SiteMarketplacePanel(
          marketplaceSnapshotLoader: ({
            required String siteId,
            required String userId,
          }) async {
            loadCount += 1;
            if (loadCount == 1) {
              return SiteMarketplaceSnapshot(
                listings: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'listing-1',
                    'title': 'AI Launch Pack',
                    'description': 'Partner-led launch support for new cohorts.',
                    'category': 'Programs',
                    'productId': 'learner-seat',
                    'price': 49,
                    'currency': 'USD',
                    'publishedAt': DateTime(2026, 3, 14),
                  },
                ],
                orders: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'order-1',
                    'siteId': siteId,
                    'productId': 'learner-seat',
                    'listingId': 'listing-1',
                    'amount': 49,
                    'currency': 'USD',
                    'status': 'paid',
                    'paidAt': DateTime(2026, 3, 14),
                  },
                ],
                entitlements: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'ent-1',
                    'siteId': siteId,
                    'productId': 'learner-seat',
                    'roles': <String>['learner'],
                    'createdAt': DateTime(2026, 3, 14),
                  },
                ],
                fulfillments: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'fulfillment-1',
                    'orderId': 'order-1',
                    'listingId': 'listing-1',
                    'siteId': siteId,
                    'status': 'pending',
                    'note': 'Awaiting partner fulfillment',
                    'updatedAt': DateTime(2026, 3, 14),
                  },
                ],
              );
            }
            throw StateError('marketplace refresh unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Launch Pack'), findsWidgets);
    expect(find.text('\$49.00 • paid'), findsOneWidget);
    expect(find.text('learner'), findsOneWidget);
    expect(find.text('pending • Awaiting partner fulfillment'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to refresh marketplace data right now. Showing the last successful data.',
      ),
      findsOneWidget,
    );
    expect(find.text('AI Launch Pack'), findsWidgets);
    expect(find.text('\$49.00 • paid'), findsOneWidget);
    expect(find.text('learner'), findsOneWidget);
    expect(find.text('pending • Awaiting partner fulfillment'), findsOneWidget);
    expect(find.text('No paid orders yet'), findsNothing);
  });
}