import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/ui/common/empty_state.dart';
import 'package:scholesa_app/ui/common/error_state.dart';
import 'package:scholesa_app/ui/common/loading.dart';
import 'package:scholesa_app/ui/error/fatal_error_screen.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

Future<void> _pumpWithTheme(
  WidgetTester tester, {
  required ThemeData theme,
  required Widget child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shared error state uses Scholesa semantic theme colors',
      (WidgetTester tester) async {
    await _pumpWithTheme(
      tester,
      theme: ScholesaTheme.light,
      child: const ErrorState(message: 'Reconnect and try again.'),
    );

    final Icon warningIcon = tester.widget<Icon>(
      find.byIcon(Icons.warning_amber_rounded),
    );
    final Text title = tester.widget<Text>(find.text('Error'));
    final Text message =
        tester.widget<Text>(find.text('Reconnect and try again.'));

    expect(warningIcon.color, ScholesaTheme.light.colorScheme.tertiary);
    expect(title.style?.color, ScholesaTheme.light.colorScheme.onSurface);
    expect(
        message.style?.color, ScholesaTheme.light.colorScheme.onSurfaceVariant);
  });

  testWidgets('shared empty and loading states use the active theme',
      (WidgetTester tester) async {
    await _pumpWithTheme(
      tester,
      theme: ScholesaTheme.dark,
      child: const EmptyState(
        icon: Icons.inbox_rounded,
        title: 'Nothing yet',
        message: 'New evidence will appear here.',
      ),
    );

    final Icon emptyIcon =
        tester.widget<Icon>(find.byIcon(Icons.inbox_rounded));
    final Text emptyTitle = tester.widget<Text>(find.text('Nothing yet'));
    final Text emptyMessage =
        tester.widget<Text>(find.text('New evidence will appear here.'));

    expect(emptyIcon.color,
        ScholesaTheme.dark.colorScheme.primary.withValues(alpha: 0.72));
    expect(emptyTitle.style?.color, ScholesaTheme.dark.colorScheme.onSurface);
    expect(emptyMessage.style?.color,
        ScholesaTheme.dark.colorScheme.onSurfaceVariant);

    await _pumpWithTheme(
      tester,
      theme: ScholesaTheme.dark,
      child: const LoadingWidget(message: 'Loading evidence'),
    );

    final Text loadingMessage =
        tester.widget<Text>(find.text('Loading evidence'));
    expect(loadingMessage.style?.color,
        ScholesaTheme.dark.colorScheme.onSurfaceVariant);
  });

  testWidgets('fatal error screen follows Scholesa error color',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ScholesaTheme.light,
        home: const FatalErrorScreen(error: 'The app needs a refresh.'),
      ),
    );
    await tester.pump();

    final Icon errorIcon =
        tester.widget<Icon>(find.byIcon(Icons.error_outline));
    final Text errorText =
        tester.widget<Text>(find.text('The app needs a refresh.'));

    expect(errorIcon.color, ScholesaTheme.light.colorScheme.error);
    expect(errorText.style?.color,
        ScholesaTheme.light.colorScheme.onSurfaceVariant);
  });
}
