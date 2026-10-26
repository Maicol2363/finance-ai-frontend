import 'package:finance_ai/app.dart';
import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _EmptyStore implements SecureCredentialStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> replace(String renewableCredential) async {}

  @override
  Future<void> delete() async {}
}

Future<GoRouter> _pumpLogin(WidgetTester tester) async {
  final router = createAppRouter(initialLocation: '/login');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureCredentialStoreProvider.overrideWithValue(_EmptyStore()),
      ],
      child: FinanceApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('login fields expose accessible names', (tester) async {
    final semantics = tester.ensureSemantics();
    final router = await _pumpLogin(tester);

    expect(find.byKey(const Key('login-email-input')), findsOneWidget);
    expect(find.byKey(const Key('login-password-input')), findsOneWidget);
    expect(find.bySemanticsLabel('Correo electrónico'), findsOneWidget);
    expect(find.bySemanticsLabel('Contraseña'), findsOneWidget);

    semantics.dispose();
    router.dispose();
  });

  testWidgets('login validation error is announced', (tester) async {
    final semantics = tester.ensureSemantics();
    final router = await _pumpLogin(tester);

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('El correo electrónico es obligatorio.'), findsOneWidget);
    expect(find.text('La contraseña es obligatoria.'), findsOneWidget);
    // After the inline error appears the native InputDecorator merges
    // label + error into one node, so assert the merged tree still
    // carries both the stable label and the error copy.
    bool semanticsContains(String needle) {
      final root = tester
          .binding
          .renderViews
          .first
          .owner!
          .semanticsOwner
          ?.rootSemanticsNode;
      if (root == null) return false;
      var found = false;
      bool visit(SemanticsNode node) {
        if (node.label.contains(needle)) found = true;
        node.visitChildren(visit);
        return true;
      }

      visit(root);
      return found;
    }

    expect(semanticsContains('Correo electrónico'), isTrue);
    expect(semanticsContains('Contraseña'), isTrue);
    expect(semanticsContains('El correo electrónico es obligatorio.'), isTrue);
    expect(semanticsContains('La contraseña es obligatoria.'), isTrue);

    semantics.dispose();
    router.dispose();
  });
}
