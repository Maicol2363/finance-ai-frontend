import 'package:finance_ai/core/router/app_shell.dart';
import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Back closes the capture wheel before leaving the shell', (
    tester,
  ) async {
    final router = _createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('expenses-create-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expenses-wheel-manual')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expenses-wheel-manual')), findsNothing);
    expect(find.text('Inicio de prueba'), findsOneWidget);
  });

  testWidgets('changing tabs closes the capture wheel', (tester) async {
    final router = _createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('expenses-create-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expenses-wheel-manual')), findsOneWidget);

    await tester.tap(find.byKey(const Key('bottom-nav-movimientos')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expenses-wheel-manual')), findsNothing);
    expect(find.text('Movimientos de prueba'), findsOneWidget);
  });
}

GoRouter _createRouter() => GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) =>
                  const Scaffold(body: Text('Inicio de prueba')),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) =>
                  const Scaffold(body: Text('Movimientos de prueba')),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) =>
                  const Scaffold(body: Text('Ajustes de prueba')),
            ),
          ],
        ),
      ],
    ),
  ],
);
