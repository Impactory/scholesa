import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/site/site_billing_page.dart';

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
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({required Widget child}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
    ],
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW')
      ],
      home: child,
    ),
  );
}

void main() {
  testWidgets(
      'site billing page shows explicit unavailable state when billing snapshot load fails',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        child: SiteBillingPage(
          firestore: FakeFirebaseFirestore(),
          loadBillingSnapshot: (String siteId) async {
            throw StateError('billing snapshot unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsWidgets);
    expect(find.text('Billing data is temporarily unavailable'), findsOneWidget);
    expect(
      find.text(
        'We could not load the current billing snapshot. Retry to check the current state.',
      ),
      findsOneWidget,
    );
    expect(find.text('No billing data yet'), findsNothing);
  });

  testWidgets(
      'site billing page shows explicit unavailable state when no billing data exists',
      (WidgetTester tester) async {
    Future<Map<String, dynamic>> loadBillingSnapshot(String siteId) async {
      return <String, dynamic>{
        'siteId': siteId,
        'summary': null,
        'invoices': <Map<String, dynamic>>[],
      };
    }

    await tester.pumpWidget(
      _buildHarness(
        child: SiteBillingPage(
          firestore: FakeFirebaseFirestore(),
          loadBillingSnapshot: loadBillingSnapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('No billing data yet'), findsOneWidget);
    expect(find.text('Billing plan unavailable'), findsOneWidget);
  });

  testWidgets('site billing page keeps stale billing summary visible after refresh failure',
      (WidgetTester tester) async {
    int loadCount = 0;
    final Finder billingRefresh = find.descendant(
      of: find.byType(AppBar),
      matching: find.byTooltip('Refresh'),
    );

    await tester.pumpWidget(
      _buildHarness(
        child: SiteBillingPage(
          firestore: FakeFirebaseFirestore(),
          loadBillingSnapshot: (String siteId) async {
            loadCount += 1;
            if (loadCount == 1) {
              return <String, dynamic>{
                'planName': 'Growth',
                'planStatus': 'Active',
                'monthlyAmount': 199,
                'currency': 'USD',
                'nextBillingDate': DateTime(2026, 4, 1).toIso8601String(),
                'activeLearnersUsed': 12,
                'activeLearnersTotal': 50,
                'educatorsUsed': 4,
                'educatorsTotal': 10,
                'storageUsedGb': 2,
                'storageTotalGb': 10,
                'invoices': <Map<String, dynamic>>[],
              };
            }
            throw StateError('billing refresh unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Growth'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);

    await tester.tap(billingRefresh);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to refresh billing data right now. Showing the last successful data.',
      ),
      findsOneWidget,
    );
    expect(find.text('Growth'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('No billing data yet'), findsNothing);
  });

  testWidgets(
      'site billing page records marketplace purchase and fulfillment state',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('marketplaceListings').doc('listing-1').set(
      <String, dynamic>{
        'partnerId': 'partner-1',
        'title': 'AI Launch Pack',
        'description': 'Partner-led launch support for new cohorts.',
        'category': 'Programs',
        'productId': 'learner-seat',
        'price': 49,
        'currency': 'USD',
        'status': 'published',
        'publishedAt': Timestamp.fromDate(DateTime(2026, 3, 14)),
      },
    );

    Future<Map<String, dynamic>> loadBillingSnapshot(String siteId) async {
      return <String, dynamic>{
        'planName': 'Growth',
        'planStatus': 'Active',
        'monthlyAmount': 199,
        'currency': 'USD',
        'nextBillingDate': DateTime(2026, 4, 1).toIso8601String(),
        'activeLearnersUsed': 12,
        'activeLearnersTotal': 50,
        'educatorsUsed': 4,
        'educatorsTotal': 10,
        'storageUsedGb': 2,
        'storageTotalGb': 10,
        'invoices': <Map<String, dynamic>>[],
      };
    }

    Future<Map<String, dynamic>?> createCheckoutIntent(
        {required String siteId,
        required String userId,
        required String productId,
        required String idempotencyKey,
        String? listingId}) async {
      await firestore
          .collection('checkoutIntents')
          .doc('intent-1')
          .set(<String, dynamic>{
        'siteId': siteId,
        'userId': userId,
        'productId': productId,
        'listingId': listingId,
        'idempotencyKey': idempotencyKey,
        'amount': '49',
        'currency': 'USD',
        'status': 'intent',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 14)),
      });
      return <String, dynamic>{
        'intentId': 'intent-1',
        'orderId': 'intent-1',
        'amount': '49',
        'currency': 'USD',
        'status': 'intent',
      };
    }

    Future<Map<String, dynamic>?> completeCheckout(
        {required String intentId, String? amount, String? currency}) async {
      await firestore.collection('checkoutIntents').doc(intentId).set(
        <String, dynamic>{
          'status': 'paid',
          'entitlementId': 'ent-1',
          'paidAt': Timestamp.fromDate(DateTime(2026, 3, 14)),
        },
        SetOptions(merge: true),
      );
      await firestore.collection('orders').doc(intentId).set(<String, dynamic>{
        'siteId': 'site-1',
        'userId': 'site-user-1',
        'productId': 'learner-seat',
        'listingId': 'listing-1',
        'amount': '49',
        'currency': 'USD',
        'status': 'paid',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 14)),
        'paidAt': Timestamp.fromDate(DateTime(2026, 3, 14)),
      });
      await firestore
          .collection('entitlements')
          .doc('ent-1')
          .set(<String, dynamic>{
        'siteId': 'site-1',
        'userId': 'site-user-1',
        'productId': 'learner-seat',
        'roles': <String>['learner'],
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 14)),
      });
      await firestore
          .collection('fulfillments')
          .doc('fulfillment-1')
          .set(<String, dynamic>{
        'orderId': intentId,
        'listingId': 'listing-1',
        'userId': 'site-user-1',
        'siteId': 'site-1',
        'status': 'pending',
        'note': 'Awaiting partner fulfillment',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 14)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 14)),
      });
      return <String, dynamic>{
        'orderId': intentId,
        'entitlementId': 'ent-1',
        'status': 'paid',
      };
    }

    await tester.pumpWidget(
      _buildHarness(
        child: SiteBillingPage(
          firestore: firestore,
          loadBillingSnapshot: loadBillingSnapshot,
          createCheckoutIntent: createCheckoutIntent,
          completeCheckout: completeCheckout,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('AI Launch Pack'), findsOneWidget);
    await tester.tap(find.text('Purchase'));
    await tester.pumpAndSettle();

    expect(find.text('Marketplace purchase recorded and fulfillment queued'),
        findsOneWidget);
    expect(find.text('pending • Awaiting partner fulfillment'), findsOneWidget);
  });

  testWidgets(
      'site billing page submits a plan change request from manage plan',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();

    Future<Map<String, dynamic>> loadBillingSnapshot(String siteId) async {
      return <String, dynamic>{
        'planName': 'Growth',
        'planStatus': 'Active',
        'monthlyAmount': 199,
        'currency': 'USD',
        'nextBillingDate': DateTime(2026, 4, 1).toIso8601String(),
        'activeLearnersUsed': 12,
        'activeLearnersTotal': 50,
        'educatorsUsed': 4,
        'educatorsTotal': 10,
        'storageUsedGb': 2,
        'storageTotalGb': 10,
        'invoices': <Map<String, dynamic>>[],
      };
    }

    Future<void> requestPlanChange(String siteId, String reason) async {
      await firestore
          .collection('billingPlanChangeRequests')
          .add(<String, dynamic>{
        'siteId': siteId,
        'status': 'pending',
        'reason': reason,
      });
    }

    await tester.pumpWidget(
      _buildHarness(
        child: SiteBillingPage(
          firestore: firestore,
          loadBillingSnapshot: loadBillingSnapshot,
          requestPlanChange: requestPlanChange,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage Plan'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Review current usage, compare plan limits, and submit a plan change request to HQ billing.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Request Change'));
    await tester.pumpAndSettle();

    expect(find.text('Plan management request submitted'), findsOneWidget);
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await firestore.collection('billingPlanChangeRequests').get();
    expect(snapshot.docs, hasLength(1));
    expect(snapshot.docs.single.data()['siteId'], 'site-1');
    expect(snapshot.docs.single.data()['reason'],
        'Requested from site billing UI');
  });

  testWidgets(
      'site billing page fails closed when plan change submission fails',
      (WidgetTester tester) async {
    Future<Map<String, dynamic>> loadBillingSnapshot(String siteId) async {
      return <String, dynamic>{
        'planName': 'Growth',
        'planStatus': 'Active',
        'monthlyAmount': 199,
        'currency': 'USD',
        'nextBillingDate': DateTime(2026, 4, 1).toIso8601String(),
        'activeLearnersUsed': 12,
        'activeLearnersTotal': 50,
        'educatorsUsed': 4,
        'educatorsTotal': 10,
        'storageUsedGb': 2,
        'storageTotalGb': 10,
        'invoices': <Map<String, dynamic>>[],
      };
    }

    Future<void> requestPlanChange(String siteId, String reason) async {
      throw Exception('callable unavailable');
    }

    await tester.pumpWidget(
      _buildHarness(
        child: SiteBillingPage(
          firestore: FakeFirebaseFirestore(),
          loadBillingSnapshot: loadBillingSnapshot,
          requestPlanChange: requestPlanChange,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request Change'));
    await tester.pumpAndSettle();

    expect(find.text('Plan management request failed'), findsOneWidget);
  });
}
