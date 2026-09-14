import 'package:finance_ai/app.dart';
import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_state.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Prevents the real controller from touching the platform secure storage.
class _MemoryStore implements SecureCredentialStore {
  _MemoryStore();

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> replace(String renewableCredential) async {
    value = renewableCredential;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

/// Boots the app on the session bootstrap route with an injected session
/// state, exactly like production does while the restore is completing.
Future<GoRouter> pumpBootstrapRouter(
  WidgetTester tester,
  AuthSessionState Function() authState,
) async {
  final router = createAppRouter(
    initialLocation: '/bootstrap',
    authState: authState,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureCredentialStoreProvider.overrideWithValue(_MemoryStore()),
      ],
      child: FinanceApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String currentPath(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  testWidgets('authenticated session leaves /bootstrap for /home', (
    tester,
  ) async {
    final router = await pumpBootstrapRouter(
      tester,
      () => const AuthSessionState(status: AuthSessionStatus.authenticated),
    );

    expect(currentPath(router), '/home');
    expect(find.byKey(const Key('home-title')), findsOneWidget);
    expect(find.text('Checking your session…'), findsNothing);
  });

  testWidgets('unauthenticated session leaves /bootstrap for /login', (
    tester,
  ) async {
    final router = await pumpBootstrapRouter(
      tester,
      () => const AuthSessionState(status: AuthSessionStatus.unauthenticated),
    );

    expect(currentPath(router), '/login');
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Checking your session…'), findsNothing);
  });
}
