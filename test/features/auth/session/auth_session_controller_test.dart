import 'dart:async';

import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_state.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const accessOne = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const accessTwo = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const renewableOne = 'ccccccccccccccccccccccccccccccccccccccccccc';
const renewableTwo = 'ddddddddddddddddddddddddddddddddddddddddddd';

IssuedAuthSession issued({
  String access = accessOne,
  String renewable = renewableOne,
}) {
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

class FakeSecureCredentialStore implements SecureCredentialStore {
  FakeSecureCredentialStore({this.value});

  String? value;
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;
  final writes = <String>[];
  int deletes = 0;

  @override
  Future<String?> read() async {
    if (failRead) {
      throw StateError('private storage read detail');
    }
    return value;
  }

  @override
  Future<void> replace(String renewableCredential) async {
    if (failWrite) {
      throw StateError('private storage write detail');
    }
    writes.add(renewableCredential);
    value = renewableCredential;
  }

  @override
  Future<void> delete() async {
    deletes += 1;
    if (failDelete) {
      throw StateError('private storage delete detail');
    }
    value = null;
  }
}

class FakeAuthSessionRepository implements AuthSessionRepository {
  IssuedAuthSession loginResult = issued();
  IssuedAuthSession refreshResult = issued(
    access: accessTwo,
    renewable: renewableTwo,
  );
  AuthSessionFailure? loginFailure;
  AuthSessionFailure? refreshFailure;
  AuthSessionFailure? logoutFailure;
  Completer<IssuedAuthSession>? pendingRefresh;
  final loginRequests = <LoginRequest>[];
  final refreshValues = <String>[];
  final logoutValues = <String>[];
  final currentAccessValues = <String>[];

  @override
  Future<IssuedAuthSession> login(LoginRequest request) async {
    loginRequests.add(request);
    if (loginFailure case final failure?) {
      throw failure;
    }
    return loginResult;
  }

  @override
  Future<IssuedAuthSession> refresh(String renewableCredential) async {
    refreshValues.add(renewableCredential);
    if (refreshFailure case final failure?) {
      throw failure;
    }
    if (pendingRefresh case final pending?) {
      return pending.future;
    }
    return refreshResult;
  }

  @override
  Future<AuthenticatedUser> currentUser(String accessCredential) async {
    currentAccessValues.add(accessCredential);
    return issued().user;
  }

  @override
  Future<void> logout(String renewableCredential) async {
    logoutValues.add(renewableCredential);
    if (logoutFailure case final failure?) {
      throw failure;
    }
  }
}

ProviderContainer containerFor(
  FakeAuthSessionRepository repository,
  FakeSecureCredentialStore store,
) {
  return ProviderContainer(
    overrides: [
      authSessionRepositoryProvider.overrideWithValue(repository),
      secureCredentialStoreProvider.overrideWithValue(store),
    ],
  );
}

Future<AuthSessionController> startController(
  ProviderContainer container,
) async {
  final controller = container.read(authSessionControllerProvider.notifier);
  await Future<void>.delayed(Duration.zero);
  return controller;
}

void main() {
  test('startup without a stored renewable credential reaches Login', () async {
    final repository = FakeAuthSessionRepository();
    final store = FakeSecureCredentialStore();
    final container = containerFor(repository, store);
    addTearDown(container.dispose);

    await startController(container);

    expect(
      container.read(authSessionControllerProvider).status,
      AuthSessionStatus.unauthenticated,
    );
    expect(repository.refreshValues, isEmpty);
  });

  test(
    'successful login stores renewable before publishing memory access',
    () async {
      final repository = FakeAuthSessionRepository();
      final store = FakeSecureCredentialStore();
      final container = containerFor(repository, store);
      addTearDown(container.dispose);
      final controller = await startController(container);

      final outcome = await controller.login(
        email: ' Person@Example.COM ',
        password: 'exact-password',
      );

      final state = container.read(authSessionControllerProvider);
      expect(outcome, LoginSubmitOutcome.success);
      expect(store.writes, [renewableOne]);
      expect(state.status, AuthSessionStatus.authenticated);
      expect(state.accessCredential, accessOne);
      expect(repository.loginRequests.single.email, 'Person@Example.COM');
      expect(repository.loginRequests.single.password, 'exact-password');
    },
  );

  test(
    'generic credential failure creates a copyable secret-free diagnostic',
    () async {
      final repository = FakeAuthSessionRepository()
        ..loginFailure = const InvalidCredentialsFailure(
          correlationId: 'login-request',
        );
      final store = FakeSecureCredentialStore();
      final container = containerFor(repository, store);
      addTearDown(container.dispose);
      final controller = await startController(container);

      await controller.login(
        email: 'private@example.com',
        password: 'private-password',
      );

      final diagnostic = container
          .read(authSessionControllerProvider)
          .diagnostic;
      expect(diagnostic?.code, 'invalid_credentials');
      expect(diagnostic?.correlationId, 'login-request');
      expect(diagnostic?.clipboardText, isNot(contains('private@example.com')));
      expect(diagnostic?.clipboardText, isNot(contains('private-password')));
    },
  );

  test(
    'valid restoration rotates secure storage and publishes Home authority',
    () async {
      final repository = FakeAuthSessionRepository();
      final store = FakeSecureCredentialStore(value: renewableOne);
      final container = containerFor(repository, store);
      addTearDown(container.dispose);

      await startController(container);

      final state = container.read(authSessionControllerProvider);
      expect(repository.refreshValues, [renewableOne]);
      expect(store.value, renewableTwo);
      expect(state.status, AuthSessionStatus.authenticated);
      expect(state.accessCredential, accessTwo);
    },
  );

  test('authoritative invalid restoration clears storage but transport failure retains it', () async {
    final invalidRepository = FakeAuthSessionRepository()
      ..refreshFailure = const InvalidSessionFailure();
    final invalidStore = FakeSecureCredentialStore(value: renewableOne);
    final invalidContainer = containerFor(invalidRepository, invalidStore);
    addTearDown(invalidContainer.dispose);
    await startController(invalidContainer);
    expect(invalidStore.value, isNull);
    expect(
      invalidContainer.read(authSessionControllerProvider).status,
      AuthSessionStatus.unauthenticated,
    );

    final offlineRepository = FakeAuthSessionRepository()
      ..refreshFailure = const AuthRetryableFailure(
        code: 'network_unavailable',
        userMessage: 'Check your connection and retry.',
      );
    final offlineStore = FakeSecureCredentialStore(value: renewableOne);
    final offlineContainer = containerFor(offlineRepository, offlineStore);
    addTearDown(offlineContainer.dispose);
    await startController(offlineContainer);
    expect(offlineStore.value, renewableOne);
    expect(
      offlineContainer.read(authSessionControllerProvider).status,
      AuthSessionStatus.restorationRetry,
    );
  });

  test(
    'secure replacement failure revokes best effort and never publishes access',
    () async {
      final repository = FakeAuthSessionRepository();
      final store = FakeSecureCredentialStore()..failWrite = true;
      final container = containerFor(repository, store);
      addTearDown(container.dispose);
      final controller = await startController(container);

      await controller.login(
        email: 'person@example.com',
        password: 'exact-password',
      );

      final state = container.read(authSessionControllerProvider);
      expect(repository.logoutValues, [renewableOne]);
      expect(state.status, AuthSessionStatus.unauthenticated);
      expect(state.accessCredential, isNull);
      expect(state.diagnostic?.code, 'secure_storage_unavailable');
    },
  );

  test('concurrent refresh callers join one rotation', () async {
    final pending = Completer<IssuedAuthSession>();
    final repository = FakeAuthSessionRepository()..pendingRefresh = pending;
    final store = FakeSecureCredentialStore();
    final container = containerFor(repository, store);
    addTearDown(container.dispose);
    final controller = container.read(authSessionControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    store.value = renewableOne;

    final first = controller.refreshSession();
    final second = controller.refreshSession();
    pending.complete(repository.refreshResult);

    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(repository.refreshValues, [renewableOne]);
  });

  test('offline logout always clears local authority and reports unconfirmed revocation', () async {
    final repository = FakeAuthSessionRepository()
      ..logoutFailure = const AuthRetryableFailure(
        code: 'network_unavailable',
        userMessage: 'Remote revocation was not confirmed.',
      );
    final store = FakeSecureCredentialStore();
    final container = containerFor(repository, store);
    addTearDown(container.dispose);
    final controller = await startController(container);
    await controller.login(
      email: 'person@example.com',
      password: 'exact-password',
    );

    await controller.logout();

    final state = container.read(authSessionControllerProvider);
    expect(store.value, isNull);
    expect(state.status, AuthSessionStatus.unauthenticated);
    expect(state.accessCredential, isNull);
    expect(state.logoutWarning?.code, 'network_unavailable');
  });
}
