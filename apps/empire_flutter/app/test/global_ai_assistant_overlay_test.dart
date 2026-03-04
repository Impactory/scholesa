import 'dart:ui' show PointerDeviceKind;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/firebase_options.dart';
import 'package:scholesa_app/runtime/global_ai_assistant_overlay.dart';

void main() {
  group('GlobalAiAssistantOverlay hover behavior', () {
    testWidgets('opens assistant sheet on hover for pointer platforms',
        (WidgetTester tester) async {
      final TargetPlatform? originalPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = originalPlatform;
      });

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final AppState appState = AppState()
        ..updateFromMeResponse(<String, dynamic>{
          'userId': 'learner_hover_test',
          'role': 'learner',
          'activeSiteId': 'site_hover_test',
          'siteIds': <String>['site_hover_test'],
          'entitlements': <Map<String, dynamic>>[],
        });

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: <Widget>[
                  SizedBox.expand(),
                  GlobalAiAssistantOverlay(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder fabFinder = find.byIcon(Icons.smart_toy_rounded);
      expect(fabFinder, findsOneWidget);

      final Offset fabCenter = tester.getCenter(fabFinder);
      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(0, 0));
      await tester.pump();
      await mouse.moveTo(fabCenter);
      await tester.pumpAndSettle();

      expect(find.text('AI Assistant'), findsWidgets);
      expect(find.text('Loading assistant…'), findsOneWidget);

      await mouse.removePointer();
    });
  });
}
