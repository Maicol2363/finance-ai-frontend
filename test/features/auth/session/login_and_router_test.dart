import 'package:finance_ai/app.dart';
import 'package:finance_ai/features/accounts/application/accounts_controller.dart';
import 'package:finance_ai/features/accounts/application/accounts_state.dart';
import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/expenses/application/expenses_controller.dart';
import 'package:finance_ai/features/expenses/application/expenses_state.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
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

class WidgetAccountsRepository implements AccountsRepository {
  @override
  Future<AccountListResult> list({required bool includeInactive}) async {
    return AccountListResult(
      accounts: const [],
      suggestedCurrencyCode: 'COP',
      supportedCurrencies: const [
        CurrencySummary(
          id: 1,
          code: 'COP',
          name: 'Colombian Peso',
          decimals: 2,
        ),
      ],
      accountTypes: AccountType.values,
    );
  }

  @override
  Future<Account> get(int accountId) => throw UnimplementedError();

  @override
  Future<Account> create(AccountCreateCommand command) =>
      throw UnimplementedError();

  @override
  Future<Account> update(int accountId, AccountUpdateCommand command) =>
      throw UnimplementedError();

  @override
  Future<Account> setActive(int accountId, {required bool isActive}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteAccount(int accountId) => throw UnimplementedError();
}

Widget appWith(WidgetAuthRepository repository, MemoryStore store) {
  return ProviderScope(
    overrides: [
      authSessionRepositoryProvider.overrideWithValue(repository),
      secureCredentialStoreProvider.overrideWithValue(store),
      accountsRepositoryProvider.overrideWithValue(WidgetAccountsRepository()),
    ],
    child: const FinanceApp(),
  );
}

void main() {
  testWidgets(
    'Login is the unauthenticated start and exposes accessible controls',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(appWith(WidgetAuthRepository(), MemoryStore()));
      await tester.pumpAndSettle();

      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.byKey(const Key('login-email-input')), findsOneWidget);
      expect(find.byKey(const Key('login-password-input')), findsOneWidget);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.bySemanticsLabel('Correo electrónico'), findsOneWidget);
      expect(find.bySemanticsLabel('Contraseña'), findsOneWidget);
      expect(
        find.byKey(const Key('login-password-visibility-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
      expect(
        find.byKey(const Key('login-create-account-button')),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'local validation is copyable and does not enter protected Home',
    (tester) async {
      await tester.pumpWidget(appWith(WidgetAuthRepository(), MemoryStore()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login-submit-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('El correo electrónico es obligatorio.'),
        findsOneWidget,
      );
      expect(find.text('La contraseña es obligatoria.'), findsOneWidget);
      expect(find.byKey(const Key('error-diagnostic-code')), findsNothing);
      expect(
        find.byKey(const Key('copy-error-details-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home-title')), findsNothing);
    },
  );

  testWidgets('login API errors use Spanish safe messages', (tester) async {
    final repository = WidgetAuthRepository()
      ..loginFailure = const InvalidCredentialsFailure();
    await tester.pumpWidget(appWith(repository, MemoryStore()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login-email-input')),
      'p@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-input')),
      'password',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('El correo electrónico o la contraseña no son correctos.'),
      findsOneWidget,
    );
    final errorPanelBottom = tester
        .getRect(find.byKey(const Key('login-error-banner')))
        .bottom;
    final emailFieldTop = tester
        .getRect(find.byKey(const Key('login-email-input')))
        .top;
    expect(emailFieldTop - errorPanelBottom, greaterThanOrEqualTo(20));
    expect(find.text('Invalid email or password.'), findsNothing);

    repository.loginFailure = const AuthRetryableFailure(
      code: 'network_unavailable',
      userMessage: 'We could not reach the server. Raw server detail.',
      technicalReason: 'socket_exception',
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FinanceApp)),
    );
    await container
        .read(authSessionControllerProvider.notifier)
        .login(email: 'p@example.com', password: 'password');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No se pudo conectar con el servicio. Revisa tu conexión e inténtalo de nuevo.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Raw server detail'), findsNothing);
  });

  testWidgets('login remains scrollable and unclipped in landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(appWith(WidgetAuthRepository(), MemoryStore()));
    await tester.pumpAndSettle();

    expect(find.text('Finance AI'), findsNothing);
    expect(find.byKey(const Key('login-email-input')), findsOneWidget);
    expect(find.byKey(const Key('login-password-input')), findsOneWidget);
    expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('login-submit-button'))).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful Login reaches Home and Logout protects it again', (
    tester,
  ) async {
    // The hub card grew (balance caption + month chips): give the window room so
    // the accounts row is not hidden behind the bottom navigation bar.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final store = MemoryStore();
    await tester.pumpWidget(appWith(WidgetAuthRepository(), store));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FinanceApp)),
    );
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

    // Inicio opens first with the Hero header and global capture wheel.
    expect(find.byKey(const Key('home-title')), findsNothing);
    expect(find.text('Saldo en cuentas'), findsOneWidget);
    expect(find.byKey(const Key('expenses-create-fab')), findsOneWidget);
    expect(store.value, renewable);

    // Movimientos tab opens from the bottom nav.
    await tester.tap(find.byKey(const Key('bottom-nav-movimientos')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-list')), findsOneWidget);

    // Android back button pops back to Inicio before exiting.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-title')), findsNothing);

    // Ajustes tab opens from the bottom nav.
    await tester.tap(find.byKey(const Key('bottom-nav-ajustes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-accounts-row')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('accounts-list')), findsOneWidget);
    expect(
      container.read(accountsControllerProvider).listStatus,
      AccountsLoadStatus.ready,
    );
    await tester.tap(find.byKey(const Key('accounts-add-button')));
    await tester.pumpAndSettle();
    expect(find.text('Nueva cuenta'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver a cuentas'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('accounts-list')), findsOneWidget);
    await tester.tap(find.byTooltip('Volver a la pantalla anterior'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-accounts-row')), findsOneWidget);
    expect(find.byKey(const Key('accounts-list')), findsNothing);

    // Navigate to Ajustes to log out.
    await tester.tap(find.byKey(const Key('bottom-nav-ajustes')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('logout-button')),
      200,
      scrollable: find
          .ancestor(
            of: find.byKey(const Key('logout-button')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-logout-button')));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.byKey(const Key('home-title')), findsNothing);
    expect(store.value, isNull);
    expect(
      container.read(accountsControllerProvider).listStatus,
      AccountsLoadStatus.initial,
    );
    expect(container.read(accountsControllerProvider).result, isNull);
    expect(
      container.read(expensesControllerProvider).listStatus,
      ExpensesLoadStatus.initial,
    );
    expect(container.read(expensesControllerProvider).result, isNull);
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

    expect(
      find.text('El correo electrónico o la contraseña no son correctos.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('error-diagnostic-code')), findsNothing);
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
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(store.value, isNull);
    },
  );
  testWidgets(
    'login lays out at the mockup phone size without a theme toggle',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(appWith(WidgetAuthRepository(), MemoryStore()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Finance AI'), findsOneWidget);
      expect(find.text('Tu dinero, más claro.'), findsOneWidget);
      expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
      expect(find.byKey(const Key('theme-toggle-button')), findsNothing);
      final introBottom = tester
          .getRect(find.text('Accede para ver tus gastos, ingresos y cuentas.'))
          .bottom;
      final emailFieldTop = tester
          .getRect(find.byKey(const Key('login-email-input')))
          .top;
      expect(emailFieldTop - introBottom, greaterThanOrEqualTo(12));

      expect(tester.takeException(), isNull);
      expect(find.text('Tu dinero, más claro.'), findsOneWidget);
      expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
    },
  );
}
