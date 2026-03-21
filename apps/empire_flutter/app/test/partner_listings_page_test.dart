import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/modules/partner/partner_models.dart';
import 'package:scholesa_app/modules/partner/partner_listings_page.dart';
import 'package:scholesa_app/modules/partner/partner_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _SequencedPartnerListingsService extends PartnerService {
  _SequencedPartnerListingsService()
      : super(
          firestoreService: FirestoreService(
            firestore: FakeFirebaseFirestore(),
            auth: _MockFirebaseAuth(),
          ),
          partnerId: 'partner-1',
        );

  bool _loading = false;
  String? _loadError;
  List<MarketplaceListing> _listingState = <MarketplaceListing>[];
  int _loadCount = 0;

  @override
  bool get isLoading => _loading;

  @override
  String? get error => _loadError;

  @override
  List<MarketplaceListing> get listings =>
      List<MarketplaceListing>.unmodifiable(_listingState);

  @override
  Future<void> loadListings() async {
    _loadCount += 1;
    _loading = true;
    _loadError = null;
    notifyListeners();
    if (_loadCount == 1) {
      _listingState = <MarketplaceListing>[
        MarketplaceListing(
          id: 'listing-1',
          partnerId: 'partner-1',
          title: 'Studio Robotics Lab',
          description: 'Hands-on robotics workshop for mixed-age learners.',
          status: ListingStatus.published,
          category: 'Programs',
          productId: 'learner-seat',
          currency: 'USD',
          price: 120,
        ),
      ];
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = false;
    _loadError = 'Failed to load listings';
    notifyListeners();
  }
}

class _FailingPartnerListingsService extends PartnerService {
  _FailingPartnerListingsService()
      : super(
          firestoreService: FirestoreService(
            firestore: FakeFirebaseFirestore(),
            auth: _MockFirebaseAuth(),
          ),
          partnerId: 'partner-1',
        );

  bool _loading = false;
  String? _loadError;

  @override
  bool get isLoading => _loading;

  @override
  String? get error => _loadError;

  @override
  Future<void> loadListings() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    _loading = false;
    _loadError = 'Failed to load listings';
    notifyListeners();
  }
}

Widget _buildHarness({
  required FirestoreService firestoreService,
  required PartnerService partnerService,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<PartnerService>.value(value: partnerService),
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
      home: const PartnerListingsPage(),
    ),
  );
}

void main() {
  testWidgets('partner listings page shows a real load error instead of fake empty state',
      (WidgetTester tester) async {
    final PartnerService partnerService = _FailingPartnerListingsService();
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        partnerService: partnerService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(
      find.text('We could not load listings right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('No Listings Yet'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('partner listings page creates a listing and persists it',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final PartnerService partnerService = PartnerService(
      firestoreService: firestoreService,
      partnerId: 'partner-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        partnerService: partnerService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('No Listings Yet'), findsOneWidget);

    await tester.tap(find.text('Create Listing'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Studio Robotics Lab');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Hands-on robotics workshop for mixed-age learners.',
    );

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Listing created and added to list'), findsOneWidget);
    expect(find.text('Studio Robotics Lab'), findsWidgets);

    final listings = await firestore.collection('marketplaceListings').get();
    expect(listings.docs.length, 1);
    expect(listings.docs.first.data()['partnerId'], 'partner-1');
    expect(listings.docs.first.data()['title'], 'Studio Robotics Lab');
  });

  testWidgets('partner listings page keeps stale listings visible after refresh failure',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );
    final PartnerService partnerService = _SequencedPartnerListingsService();

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        partnerService: partnerService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Studio Robotics Lab'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded).first);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Unable to refresh listings right now. Showing the last successful data.'),
      findsOneWidget,
    );
    expect(find.text('Studio Robotics Lab'), findsOneWidget);
  });
}