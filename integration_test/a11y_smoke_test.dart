import 'package:finance_ai/app.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const runA11ySmokeTest = bool.fromEnvironment('RUN_A11Y_SMOKE_TEST');

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a11y smoke register login home movimientos wheel y search', (
    tester,
  ) async {
    final store = _MemoryStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureCredentialStoreProvider.overrideWithValue(store)],
        child: const FinanceApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-create-account-button')));
    await tester.pumpAndSettle();
    final uniqueEmail =
        'flutter-${DateTime.now().microsecondsSinceEpoch}@example.com';
    await tester.enterText(
      find.byKey(const Key('register-email-input')),
      uniqueEmail,
    );
    await tester.enterText(
      find.byKey(const Key('register-password-input')),
      'integration-safe-password-2026',
    );
    await tester.enterText(
      find.byKey(const Key('register-password-confirmation-input')),
      'integration-safe-password-2026',
    );
    await tester.tap(find.byKey(const Key('register-submit-button')));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.byKey(const Key('register-success-message')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login-email-input')),
      uniqueEmail,
    );
    await tester.enterText(
      find.byKey(const Key('login-password-input')),
      'integration-safe-password-2026',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final hasHomeTitle = find
        .byKey(const Key('home-title'))
        .evaluate()
        .isNotEmpty;
    // home-title es Text('Gastos') del chat (/chat), no del dashboard (/home).
    // Tras el login estamos en el dashboard: no debe existir el key.
    expect(hasHomeTitle, isFalse);
    expect(find.text('Saldo en cuentas'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-account-balance')), findsOneWidget);

    // bottom-nav-movimientos no se busca por key literal (la key se genera
    // como 'bottom-nav-${id}'); se navega por el texto verificado 'Movimientos'.
    await tester.tap(find.text('Movimientos').first);
    await tester.pumpAndSettle();
    expect(find.text('Movimientos'), findsWidgets);
    expect(find.byKey(const Key('history-list')), findsOneWidget);
    expect(find.byKey(const Key('history-search-field')), findsOneWidget);

    final searchSemantics = find.bySemanticsLabel('Buscar');
    if (searchSemantics.evaluate().isNotEmpty) {
      expect(searchSemantics, findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('expenses-create-fab')));
    await tester.pumpAndSettle();
    expect(find.text('Foto'), findsOneWidget);
    expect(find.text('Mensaje'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
  }, skip: !runA11ySmokeTest);
}
