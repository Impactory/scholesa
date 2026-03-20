import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fixed workflow translations do not keep stale placeholder wording', () {
    final String parentI18n =
        File('lib/i18n/parent_surface_i18n.dart').readAsStringSync();
    final String learnerI18n =
        File('lib/i18n/learner_surface_i18n.dart').readAsStringSync();
    final String settingsPage =
        File('lib/modules/settings/settings_page.dart').readAsStringSync();

    expect(parentI18n,
        isNot(contains('Session reminders are not available in the app yet')));
    expect(parentI18n,
        isNot(contains('Portfolio sharing is not available in the app yet')));
    expect(parentI18n,
        isNot(contains('Portfolio downloads are not available in the app yet')));

    expect(learnerI18n,
        isNot(contains('Portfolio profile editing is not available in the app yet')));
    expect(learnerI18n,
        isNot(contains('Portfolio share links are not available in the app yet')));

    expect(settingsPage,
        isNot(contains('Feedback sends through your email app so support can follow up with context.')));

    expect(parentI18n, contains('Request a reminder for upcoming sessions.'));
    expect(parentI18n,
        contains('Request portfolio sharing through the approved parent-safe review flow.'));
    expect(parentI18n,
        contains('Download a portfolio summary for offline review.'));

    expect(learnerI18n, contains('Update your portfolio profile in the app.'));
    expect(learnerI18n, contains('Copy a portfolio summary for sharing.'));

    expect(settingsPage,
        contains('Feedback is submitted in-app so support can follow up with context.'));
  });
}