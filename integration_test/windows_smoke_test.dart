import 'package:finance_ai/app.dart';
import 'package:finance_ai/features/auth/register/data/auth_repository.dart';
import 'package:finance_ai/features/auth/register/domain/registration_models.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _SuccessfulRegistrationRepository implements AuthRepository {
  @override
  Future<RegistrationResult> register(RegistrationRequest request) async {
    return RegistrationResult(
      user: RegisteredUser(
        id: 1,
        email: request.email,
        preferredCurrency: 'COP',
      ),
      message: 'Account created successfully. You can now log in.',
    );
  }
}

class _UnavailableRegistrationRepository implements AuthRepository {
  @override
  Future<RegistrationResult> register(RegistrationRequest request) {
    throw const RegistrationRetryableFailure(
      code: 'network_unavailable',
      userMessage: 'We could not reach the service. Check your connection and try again.',
      correlationId: 'windows-smoke-request',
      technicalReason: 'connection_failure',
    );
  }
}

class _MemoryStore implements SecureCredentialStore {
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

class _SuccessfulSessionRepository implements AuthSessionRepository {
  static const access = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  static const renewable = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  IssuedAuthSession get _issued {
    final now = DateTime.now().toUtc();
    return IssuedAuthSession(
      user: const AuthenticatedUser(
        id: 42,
        email: 'desktop@example.com',
        preferredCurrency: 'COP',
      ),
      accessCredential: access,
      renewableCredential: renewable,
      accessExpiresAt: now.add(const Duration(minutes: 15)),
      renewableExpiresAt: now.add(const Duration(days: 30)),
      absoluteExpiresAt: now.add(const Duration(days: 90)),
    );
  }

  @override
  Future<IssuedAuthSession> login(LoginRequest request) async => _issued;

  @override
  Future<IssuedAuthSession> refresh(String renewableCredential) async =>
      _issued;

  @override
  Future<AuthenticatedUser> currentUser(String accessCredential) async =>
      _issued.user;

  @override
  Future<void> logout(String renewableCredential) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the native Windows client completes the shared registration UI flow',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureCredentialStoreProvider.overrideWithValue(_MemoryStore()),
            authRepositoryProvider.overrideWithValue(
              _SuccessfulRegistrationRepository(),
            ),
          ],
          child: const FinanceApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login-create-account-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('register-email-input')),
        'desktop@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('register-password-input')),
        'desktop-safe-password',
      );
      await tester.enterText(
        find.byKey(const Key('register-password-confirmation-input')),
        'desktop-safe-password',
      );
      await tester.tap(find.byKey(const Key('register-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byKey(const Key('register-success-message')), findsOneWidget);
    },
    skip: defaultTargetPlatform != TargetPlatform.windows,
  );

  testWidgets('the native Windows client exposes a copyable safe failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureCredentialStoreProvider.overrideWithValue(_MemoryStore()),
          authRepositoryProvider.overrideWithValue(
            _UnavailableRegistrationRepository(),
          ),
        ],
        child: const FinanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login-create-account-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('register-email-input')),
      'desktop@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register-password-input')),
      'desktop-safe-password',
    );
    await tester.enterText(
      find.byKey(const Key('register-password-confirmation-input')),
      'desktop-safe-password',
    );
    await tester.tap(find.byKey(const Key('register-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Error code: network_unavailable'), findsOneWidget);
    expect(find.byKey(const Key('copy-error-details-button')), findsOneWidget);
  }, skip: defaultTargetPlatform != TargetPlatform.windows);

  testWidgets('the native Windows client protects Home and clears on Logout', (
    tester,
  ) async {
    final store = _MemoryStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureCredentialStoreProvider.overrideWithValue(store),
          authSessionRepositoryProvider.overrideWithValue(
            _SuccessfulSessionRepository(),
          ),
        ],
        child: const FinanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-email-input')),
      'desktop@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-input')),
      'desktop-safe-password',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-title')), findsOneWidget);
    expect(store.value, _SuccessfulSessionRepository.renewable);

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('home-title')), findsNothing);
    expect(store.value, isNull);
  }, skip: defaultTargetPlatform != TargetPlatform.windows);

  testWidgets(
    'Windows secure storage reads replaces and deletes a synthetic value',
    (tester) async {
      const syntheticKey = 'finance_ai.integration_test.renewable_session';
      const firstValue = 'ccccccccccccccccccccccccccccccccccccccccccc';
      const secondValue = 'ddddddddddddddddddddddddddddddddddddddddddd';
      const store = FlutterSecureCredentialStore(
        FlutterSecureStorage(),
        credentialKey: syntheticKey,
      );

      await store.delete();
      try {
        await store.replace(firstValue);
        expect(await store.read(), firstValue);
        await store.replace(secondValue);
        expect(await store.read(), secondValue);
      } finally {
        await store.delete();
      }
      expect(await store.read(), isNull);
    },
    skip: defaultTargetPlatform != TargetPlatform.windows,
  );
}
