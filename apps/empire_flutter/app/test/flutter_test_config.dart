import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/services/telemetry_service.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  TelemetryService.instance.configureDispatcher(
    (Map<String, dynamic> _) async {},
  );
  try {
    await TelemetryService.runWithDispatcher(
      (Map<String, dynamic> _) async {},
      () async {
        await testMain();
      },
    );
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}
