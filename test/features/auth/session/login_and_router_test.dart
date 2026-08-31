import 'package:finance_ai/app.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const access = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const renewable = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

IssuedAuthSession issued() {
  final now = DateTime.utc(2026, 8, 30);
  return IssuedAuthSession(
    user: const AuthenticatedUser(
      id: 42,
      email: 'person@example.com',
      preferredCurrency: 'COP',
    ),
    accessCredential: access,
    renewableCredential: renewable,
    accessExpiresAt: now.add(const Duration(minutes: 15)),
    renewableExpiresAt: now.add(const Duration(days: 30)),
    absoluteExpiresAt: now.add(const Duration(days: 90)),
  );
}

class MemoryStore implements SecureCredentialStore {
  MemoryStore([this.value]);

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

class WidgetAuthRepository implements AuthSessionRepository {
  AuthSessionFailure? loginFailure;
  AuthSessionFailure? refreshFailure;
  AuthSessionFailure? logoutFailure;

  @override
  Future<IssuedAuthSession> login(LoginRequest request) async {
    if (loginFailure case final failure?) {
      throw failure;
    }
    return issued();
  }

  @override
  Future<IssuedAuthSession> refresh(String renewableCredential) async {
    if (refreshFailure case final failure?) {
      throw failure;
    }
    return issued();
  }

  @override
  Future<AuthenticatedUser> currentUser(String accessCredential) async {
    return issued().user;
  }

  @override
  Future<void> logout(String renewableCredential) async {
    if (logoutFailure case final failure?) {
      throw failure;
    }
  }
}

Widget appWith(WidgetAuthRepository repository, MemoryStore store) {
  return ProviderScope(
    overrides: [
      authSessionRepositoryProvider.overrideWithValue(repository),
      secureCredentialStoreProvider.overrideWithValue(store),
    ],
    child: const FinanceApp(),
  );
}

void main() {
  testWidgets(
    'Login is the unauthenticated start and exposes accessible controls',
    (tester) async {
      await tester.pumpWidget(appWith(WidgetAuthRepository(), MemoryStore()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byKey(const Key('login-email-input')), findsOneWidget);
      expect(find.byKey(const Key('login-password-input')), findsOneWidget);
      expect(
        find.byKey(const Key('login-password-visibility-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
      expect(
        find.byKey(const Key('login-create-account-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'local validation is copyable and does not enter protected Home',
    (tester) async {
      await tester.pumpWidget(appWith(WidgetAuthRepository(), MemoryStore()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
      expect(find.text('Error code: login_invalid'), findsOneWidget);
      expect(
        find.byKey(const Key('copy-error-details-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home-title')), findsNothing);
    },
  );

  testWidgets('successful Login reaches Home and Logout protects it again', (
    tester,
  ) async {
    final store = MemoryStore();
    await tester.pumpWidget(appWith(WidgetAuthRepository(), store));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login-email-input')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-input')),
      'exact-password',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-title')), findsOneWidget);
    expect(find.textContaining('person@example.com'), findsOneWidget);
    expect(store.value, renewable);

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('home-title')), findsNothing);
    expect(store.value, isNull);
  });

  testWidgets('generic invalid credentials remain safe and editable', (
    tester,
  ) async {
    final repository = WidgetAuthRepository()
      ..loginFailure = const InvalidCredentialsFailure(
        correlationId: 'widget-login-request',
      );
    await tester.pumpWidget(appWith(repository, MemoryStore()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login-email-input')),
      'private@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-input')),
      'private-password',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(find.text('Error code: invalid_credentials'), findsOneWidget);
    expect(find.byKey(const Key('login-email-input')), findsOneWidget);
  });

  testWidgets(
    'offline restoration blocks Home and offers retry or local clear',
    (tester) async {
      final repository = WidgetAuthRepository()
        ..refreshFailure = const AuthRetryableFailure(
          code: 'network_unavailable',
          userMessage: 'Check your connection and retry.',
        );
      final store = MemoryStore(renewable);
      await tester.pumpWidget(appWith(repository, store));
      await tester.pumpAndSettle();

      expect(find.text('Session restoration needs attention'), findsOneWidget);
      expect(find.byKey(const Key('restore-error-banner')), findsOneWidget);
      expect(find.byKey(const Key('restore-retry-button')), findsOneWidget);
      expect(find.byKey(const Key('restore-clear-button')), findsOneWidget);
      expect(find.byKey(const Key('home-title')), findsNothing);

      await tester.tap(find.byKey(const Key('restore-clear-button')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(store.value, isNull);
    },
  );
}
