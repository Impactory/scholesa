import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app shell does not float duplicate session chrome over routes', () {
    final String source = File('lib/main.dart').readAsStringSync();

    expect(source, isNot(contains('GlobalSessionMenu(')));
    expect(source, contains('GlobalAiAssistantOverlay('));
  });
}
