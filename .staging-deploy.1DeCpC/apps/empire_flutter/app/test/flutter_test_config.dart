import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/services/telemetry_service.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await TelemetryService.runWithDispatcher(
    (Map<String, dynamic> _) async {},
    () async {
      await testMain();
    },
  );
}
