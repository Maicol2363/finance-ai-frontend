import 'package:finance_ai/app.dart';
import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_state.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/notifications/application/notifications_controller.dart';
import 'package:finance_ai/features/notifications/application/notifications_state.dart';
import 'package:finance_ai/features/notifications/data/notifications_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../notifications_test_helpers.dart';

const _access = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _renewable = 'ccccccccccccccccccccccccccccccccccccccccccc';

class _MemoryStore implements SecureCredentialStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> replace(String renewableCredential) async {
    value = renewableCredential;
  }
}

class _SessionRepository implements AuthSessionRepository {
  IssuedAuthSession get issued {
    final now = DateTime.utc(2026, 11, 16);
    return IssuedAuthSession(
      user: const AuthenticatedUser(
        id: 42,
        email: 'person@example.com',
        preferredCurrency: 'COP',
      ),
      accessCredential: _access,
      renewableCredential: _renewable,
      accessExpiresAt: now.add(const Duration(minutes: 15)),
      renewableExpiresAt: now.add(const Duration(days: 30)),
      absoluteExpiresAt: now.add(const Duration(days: 90)),
    );
  }

  @override
  Future<AuthenticatedUser> currentUser(String accessCredential) async =>
      issued.user;

  @override
  Future<IssuedAuthSession> login(LoginRequest request) async => issued;

  @override
  Future<void> logout(String renewableCredential) async {}

  @override
  Future<IssuedAuthSession> refresh(String renewableCredential) async => issued;
}

void main() {
  testWidgets(
    'signing out clears the notification settings and a pending code',
    (tester) async {
      final repository = FakeNotificationsRepository(
        initial: preferences(verified: false, enabled: false),
      );
      final router = createAppRouter(initialLocation: '/login');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            httpClientProvider.overrideWithValue(
              MockClient((_) async => http.Response('{}', 500)),
            ),
            secureCredentialStoreProvider.overrideWithValue(_MemoryStore()),
            authSessionRepositoryProvider.overrideWithValue(
              _SessionRepository(),
            ),
            notificationsRepositoryProvider.overrideWithValue(repository),
          ],
          child: FinanceApp(router: router),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FinanceApp)),
      );
      final session = container.read(authSessionControllerProvider.notifier);
      expect(
        await session.login(
          email: 'person@example.com',
          password: 'safe-password',
        ),
        LoginSubmitOutcome.success,
      );
      await tester.pumpAndSettle();
      final notifications = container.read(
        notificationsControllerProvider.notifier,
      );
      await notifications.load();
      await notifications.startVerification();
      final before = container.read(notificationsControllerProvider);
      expect(before.preferences?.emailHint, 'a***@example.com');
      expect(before.verification, isNotNull);

      await session.logout();
      await tester.pumpAndSettle();

      final after = container.read(notificationsControllerProvider);
      expect(after.loadStatus, NotificationsLoadStatus.initial);
      expect(after.preferences, isNull);
      expect(after.verification, isNull);
      expect(after.verificationStep, VerificationStep.idle);
    },
  );
}
