import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app shell mounts the global session menu with the root navigator', () {
    final String source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('GlobalSessionMenu('));
    expect(source, contains('navigatorKey: _rootNavigatorKey'));
  });
}
