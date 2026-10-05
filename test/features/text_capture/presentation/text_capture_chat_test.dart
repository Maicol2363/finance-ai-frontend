import 'dart:async';

import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/features/accounts/application/accounts_controller.dart';
import 'package:finance_ai/features/categories/application/categories_controller.dart';
import 'package:finance_ai/features/text_capture/application/text_capture_controller.dart';
import 'package:finance_ai/features/text_capture/domain/text_capture_models.dart';
import 'package:finance_ai/features/text_capture/presentation/text_capture_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../text_capture_test_support.dart';

const messageText = 'Almorcé en Subway 15900 con efectivo';

Future<ProviderContainer> pumpChat(
  WidgetTester tester,
  FakeTextCaptureRepository repository, {
  Size size = const Size(420, 900),
  double textScale = 1.0,
  ThemeData? theme,
  FakeExpensesRepository? expenses,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: SafeArea(child: TextCaptureChat())),
      ),
      GoRoute(
        path: '/expenses/new',
        builder: (_, _) => const Scaffold(body: Text('manual-form')),
      ),
      GoRoute(
        path: '/expenses/:id',
        builder: (_, state) =>
            Scaffold(body: Text('expense-${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: baseOverrides(
        repository: repository,
        expensesRepository: expenses,
      ),
      child: MaterialApp.router(
        routerConfig: router,
        theme: theme ?? AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(TextCaptureChat)),
  );
  // Gastos loads these lists when it opens; the review card edits against them.
  await container.read(accountsControllerProvider.notifier).load();
  await container.read(categoriesControllerProvider.notifier).load();
  await tester.pumpAndSettle();
  return container;
}

Future<void> send(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('chat-composer-field')), text);
  await tester.pump();
  await tester.tap(find.byKey(const Key('chat-send-button')));
  await tester.pumpAndSettle();
}

Finder byKey(String key) => find.byKey(Key(key));

void main() {
  testWidgets('opens with the assistant welcome and example prompts', (
    tester,
  ) async {
    await pumpChat(tester, FakeTextCaptureRepository());

    expect(
      find.textContaining('Cuéntame qué pasó con tu dinero'),
      findsOneWidget,
    );
    expect(byKey('chat-composer-field'), findsOneWidget);
    expect(byKey('chat-suggestion-0'), findsOneWidget);
    expect(find.text('Cuéntame qué pasó…'), findsOneWidget);

    await tester.tap(byKey('chat-suggestion-2'));
    await tester.pump();

    final field = tester.widget<TextField>(byKey('chat-composer-field'));
    expect(field.controller!.text, 'Pasé 50 mil de Nequi a efectivo');
  });

  testWidgets('send is disabled until there is text', (tester) async {
    await pumpChat(tester, FakeTextCaptureRepository());

    IconButton button() => tester.widget<IconButton>(byKey('chat-send-button'));
    expect(button().onPressed, isNull);

    await tester.enterText(byKey('chat-composer-field'), '   ');
    await tester.pump();
    expect(button().onPressed, isNull);

    await tester.enterText(byKey('chat-composer-field'), 'gasté 5 mil');
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });

  testWidgets('a message shows a compact review and accepting takes one tap', (
    tester,
  ) async {
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    final expenses = FakeExpensesRepository();
    await pumpChat(tester, repository, expenses: expenses);

    await send(tester, messageText);

    expect(find.text(messageText), findsOneWidget);
    expect(byKey('proposal-card'), findsOneWidget);
    expect(find.text('✨ IA · Entendí un gasto'), findsOneWidget);
    expect(find.text('listo para confirmar'), findsOneWidget);
    expect(find.text(r'$ 15.900 COP'), findsOneWidget);
    expect(find.text('Almuerzo en Subway'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(repository.confirmCalls, isEmpty);

    await tester.tap(byKey('proposal-confirm'));
    await tester.pumpAndSettle();

    expect(repository.confirmCalls, hasLength(1));
    final sent = repository.confirmCalls.single.$2.toJson();
    expect(sent['intent'], 'expense');
    expect(sent['amount'], '15900.00');
    expect(sent['account_id'], 1);
    expect(sent['category_id'], 10);
    expect(sent['description'], 'Almuerzo en Subway');
    expect(byKey('proposal-card'), findsNothing);
    expect(byKey('confirmed-card'), findsOneWidget);
    expect(find.text('Gasto registrado'), findsOneWidget);
    expect(find.text('Ver detalle'), findsOneWidget);
    expect(expenses.listCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('a low confidence proposal asks for a careful review', (
    tester,
  ) async {
    final repository = FakeTextCaptureRepository(
      proposals: [
        proposal(
          oneTap: false,
          confidence: 0.5,
          notes: ['Revisa los datos antes de confirmar.'],
        ),
      ],
    );
    await pumpChat(tester, repository);

    await send(tester, messageText);

    expect(find.text('revisa los datos'), findsOneWidget);
    expect(find.text('Revisa los datos antes de confirmar.'), findsOneWidget);
    expect(byKey('proposal-confirm'), findsOneWidget);
  });

  testWidgets('edit in place changes what Accept sends', (tester) async {
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    await pumpChat(tester, repository);
    await send(tester, messageText);

    await tester.tap(byKey('proposal-edit'));
    await tester.pumpAndSettle();
    expect(byKey('proposal-save-edit'), findsOneWidget);
    expect(byKey('proposal-intent-selector'), findsOneWidget);

    await tester.enterText(byKey('proposal-amount-field'), '20000');
    await tester.enterText(byKey('proposal-description-field'), 'Cena con Ana');
    await tester.tap(byKey('proposal-account-field'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nequi · COP').last);
    await tester.pumpAndSettle();
    await tester.tap(byKey('proposal-save-edit'));
    await tester.pumpAndSettle();

    expect(byKey('proposal-save-edit'), findsNothing);
    expect(find.text(r'$ 20.000 COP'), findsOneWidget);
    expect(find.text('Cena con Ana'), findsOneWidget);
    expect(find.text('Nequi'), findsOneWidget);

    await tester.tap(byKey('proposal-confirm'));
    await tester.pumpAndSettle();

    final sent = repository.confirmCalls.single.$2.toJson();
    expect(sent['amount'], '20000.00');
    expect(sent['account_id'], 2);
    expect(sent['description'], 'Cena con Ana');
  });

  testWidgets('cancelling an edit restores the proposal', (tester) async {
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    await pumpChat(tester, repository);
    await send(tester, messageText);

    await tester.tap(byKey('proposal-edit'));
    await tester.pumpAndSettle();
    await tester.enterText(byKey('proposal-amount-field'), '1');
    await tester.tap(byKey('proposal-cancel-edit'));
    await tester.pumpAndSettle();

    expect(find.text(r'$ 15.900 COP'), findsOneWidget);
  });

  testWidgets('an invalid edit is explained and nothing is sent', (
    tester,
  ) async {
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    await pumpChat(tester, repository);
    await send(tester, messageText);

    await tester.tap(byKey('proposal-edit'));
    await tester.pumpAndSettle();
    await tester.enterText(byKey('proposal-amount-field'), '');
    await tester.tap(byKey('proposal-save-edit'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un monto mayor que cero.'), findsOneWidget);
    expect(byKey('proposal-save-edit'), findsOneWidget);

    await tester.enterText(byKey('proposal-amount-field'), '0');
    await tester.tap(byKey('proposal-save-edit'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un monto mayor que cero.'), findsOneWidget);
    expect(repository.confirmCalls, isEmpty);
  });

  testWidgets(
    'Accept with an invalid amount reopens the editor instead of sending',
    (tester) async {
      final repository = FakeTextCaptureRepository(
        proposals: [proposal(amount: null, oneTap: false)],
      );
      await pumpChat(tester, repository);
      await send(tester, 'gasté algo');

      await tester.tap(byKey('proposal-confirm'));
      await tester.pumpAndSettle();

      expect(byKey('proposal-save-edit'), findsOneWidget);
      expect(find.text('Escribe un monto mayor que cero.'), findsOneWidget);
      expect(repository.confirmCalls, isEmpty);
    },
  );

  testWidgets('switching the type in place turns an expense into an income', (
    tester,
  ) async {
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    await pumpChat(tester, repository);
    await send(tester, messageText);

    await tester.tap(byKey('proposal-edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingreso'));
    await tester.pumpAndSettle();
    expect(byKey('proposal-source-field'), findsOneWidget);
    expect(byKey('proposal-category-field'), findsNothing);
    await tester.tap(byKey('proposal-save-edit'));
    await tester.pumpAndSettle();
    expect(find.text('✨ IA · Entendí un ingreso'), findsOneWidget);
    expect(find.text('Entra a'), findsOneWidget);

    await tester.tap(byKey('proposal-confirm'));
    await tester.pumpAndSettle();

    final sent = repository.confirmCalls.single.$2.toJson();
    expect(sent['intent'], 'income');
    expect(sent.containsKey('category_id'), isFalse);
  });

  testWidgets(
    'a transfer shows both accounts and needs the arrived amount across currencies',
    (tester) async {
      final repository = FakeTextCaptureRepository(
        proposals: [
          proposal(
            intent: 'transfer',
            category: null,
            description: null,
            amount: '400000.00',
            destinationAccount: const {
              'id': 4,
              'name': 'Dólares',
              'currency_code': 'USD',
            },
            destinationAmount: '100.00',
          ),
        ],
      );
      await pumpChat(tester, repository);

      await send(tester, 'pasé 400 mil de efectivo a dólares');

      expect(find.text('✨ IA · Entendí una transferencia'), findsOneWidget);
      expect(find.text('Monto que sale'), findsOneWidget);
      expect(find.text('De'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Dólares'), findsOneWidget);
      expect(find.text('Monto que llega'), findsOneWidget);
      expect(find.text(r'$ 100 USD'), findsOneWidget);

      await tester.tap(byKey('proposal-confirm'));
      await tester.pumpAndSettle();

      final sent = repository.confirmCalls.single.$2.toJson();
      expect(sent['intent'], 'transfer');
      expect(sent['destination_account_id'], 4);
      expect(sent['destination_amount'], '100.00');
    },
  );

  testWidgets('only an ambiguous message asks, with tappable options', (
    tester,
  ) async {
    final repository = FakeTextCaptureRepository(
      proposals: [accountQuestion(), proposal(revision: 2)],
    );
    await pumpChat(tester, repository);

    await send(tester, 'gasté 15 mil');

    expect(byKey('clarification-card'), findsOneWidget);
    expect(find.text('¿Con qué cuenta pagaste?'), findsOneWidget);
    expect(find.text('Entendí: Gasto · \$ 15.900'), findsOneWidget);
    expect(byKey('proposal-card'), findsNothing);

    await tester.tap(byKey('clarification-option-2'));
    await tester.pumpAndSettle();

    final call = repository.proposeCalls.last;
    expect(call.choice, (field: 'account', value: '2'));
    expect(call.text, isNull);
    expect(find.text('Nequi'), findsWidgets);
    expect(byKey('clarification-card'), findsNothing);
    expect(byKey('proposal-card'), findsOneWidget);
  });

  testWidgets('a typed question explains where to answer', (tester) async {
    final repository = FakeTextCaptureRepository(
      proposals: [
        proposal(
          status: 'needs_clarification',
          oneTap: false,
          amount: null,
          clarification: const {
            'field': 'amount',
            'question': '¿De cuánto fue?',
          },
        ),
        proposal(revision: 2),
      ],
    );
    await pumpChat(tester, repository);

    await send(tester, 'almorcé en Subway');

    expect(find.text('¿De cuánto fue?'), findsOneWidget);
    expect(
      find.text('Respóndeme escribiendo en el cuadro de abajo.'),
      findsOneWidget,
    );
    expect(find.text('Escribe tu respuesta…'), findsOneWidget);

    await send(tester, '15900');

    final call = repository.proposeCalls.last;
    expect(call.text, '15900');
    expect(call.proposalId, isNotNull);
  });

  testWidgets('a typed correction is sent against the open proposal', (
    tester,
  ) async {
    final repository = FakeTextCaptureRepository(
      proposals: [
        proposal(),
        proposal(revision: 2, amount: '20000.00'),
      ],
    );
    await pumpChat(tester, repository);
    await send(tester, messageText);

    expect(find.text('Corrige o completa el borrador…'), findsOneWidget);
    await send(tester, 'mejor fueron 20 mil');

    expect(repository.proposeCalls.last.proposalId, isNotNull);
    expect(byKey('proposal-card'), findsOneWidget);
    expect(find.text(r'$ 20.000 COP'), findsOneWidget);
    expect(find.text(r'$ 15.900 COP'), findsNothing);
  });

  testWidgets('discarding removes the card and forgets the draft', (
    tester,
  ) async {
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    await pumpChat(tester, repository);
    await send(tester, messageText);

    await tester.tap(byKey('proposal-discard'));
    await tester.pumpAndSettle();

    expect(byKey('proposal-card'), findsNothing);
    expect(find.textContaining('No se guardó nada'), findsOneWidget);
    expect(repository.discardCalls, hasLength(1));
    expect(repository.confirmCalls, isEmpty);
  });

  testWidgets('a message that is not an operation gets a plain answer', (
    tester,
  ) async {
    final repository = FakeTextCaptureRepository(
      proposals: [
        proposal(
          status: 'unrecognized',
          intent: null,
          amount: null,
          account: null,
          category: null,
          description: null,
          oneTap: false,
          message:
              'No encontré un gasto, ingreso o transferencia en tu mensaje.',
        ),
      ],
    );
    await pumpChat(tester, repository);

    await send(tester, 'hola');

    expect(
      find.text('No encontré un gasto, ingreso o transferencia en tu mensaje.'),
      findsOneWidget,
    );
    expect(byKey('proposal-card'), findsNothing);
  });

  testWidgets(
    'a failed message offers retry, the manual form and a copyable report',
    (tester) async {
      final repository = FakeTextCaptureRepository(
        proposals: [
          const TextCaptureFailure(
            code: 'text_capture_unavailable',
            userMessage: 'No pude leer tu mensaje ahora. Reintenta o usa el formulario manual.',
            correlationId: 'corr-9',
            technicalReason: 'http_503',
          ),
          proposal(),
        ],
      );
      await pumpChat(tester, repository);

      await send(tester, messageText);

      expect(byKey('chat-failure'), findsOneWidget);
      expect(find.textContaining('No pude leer tu mensaje'), findsOneWidget);
      expect(find.text('Error code: text_capture_unavailable'), findsOneWidget);
      expect(byKey('copy-error-details-button'), findsOneWidget);
      expect(byKey('chat-manual'), findsOneWidget);
      // The user's own text stays in the conversation, not in the report.
      expect(find.text(messageText), findsOneWidget);

      await tester.tap(byKey('chat-retry'));
      await tester.pumpAndSettle();

      expect(byKey('chat-failure'), findsNothing);
      expect(byKey('proposal-card'), findsOneWidget);
      expect(repository.proposeCalls, hasLength(2));
      expect(find.text(messageText), findsOneWidget);
    },
  );

  testWidgets('the manual form stays one tap away from a failure', (
    tester,
  ) async {
    final repository = FakeTextCaptureRepository(
      proposals: [
        const TextCaptureFailure(
          code: 'network_unavailable',
          userMessage: 'Sin conexión.',
        ),
      ],
    );
    await pumpChat(tester, repository);
    await send(tester, messageText);

    await tester.tap(byKey('chat-manual'));
    await tester.pumpAndSettle();

    expect(find.text('manual-form'), findsOneWidget);
  });

  testWidgets(
    'a failure that cannot be retried hides Retry but keeps the way out',
    (tester) async {
      final repository = FakeTextCaptureRepository(
        proposals: [
          const TextCaptureFailure(
            code: 'text_proposal_not_found',
            userMessage: 'Ese borrador ya no está disponible.',
            isRetryable: false,
          ),
        ],
      );
      await pumpChat(tester, repository);
      await send(tester, messageText);

      expect(byKey('chat-retry'), findsNothing);
      expect(byKey('chat-manual'), findsOneWidget);

      await tester.tap(byKey('chat-dismiss'));
      await tester.pumpAndSettle();
      expect(byKey('chat-failure'), findsNothing);
    },
  );

  testWidgets('a failed Accept keeps the card and says it is safe to retry', (
    tester,
  ) async {
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    repository.confirmQueue.add(
      const TextCaptureFailure(
        code: 'network_unavailable',
        userMessage:
            'No pudimos confirmar si se guardó. Reintenta: no se duplicará.',
        isMutationOutcomeUncertain: true,
      ),
    );
    await pumpChat(tester, repository);
    await send(tester, messageText);

    await tester.tap(byKey('proposal-confirm'));
    await tester.pumpAndSettle();

    expect(byKey('proposal-card'), findsOneWidget);
    expect(find.textContaining('no se duplicará'), findsOneWidget);
    expect(
      find.text('Puedes reintentar: no se guardará dos veces.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(byKey('proposal-confirm'));
    await tester.pumpAndSettle();

    expect(repository.confirmCalls, hasLength(2));
    expect(byKey('confirmed-card'), findsOneWidget);
  });

  testWidgets(
    'while the assistant reads, the user sees progress and cannot double send',
    (tester) async {
      final repository = FakeTextCaptureRepository(proposals: [proposal()]);
      repository.gate = Completer<void>();
      await pumpChat(tester, repository);

      await tester.enterText(byKey('chat-composer-field'), messageText);
      await tester.pump();
      await tester.tap(byKey('chat-send-button'));
      await tester.pump();

      expect(byKey('chat-thinking'), findsOneWidget);
      expect(find.text('Leyendo tu mensaje…'), findsOneWidget);
      expect(
        tester.widget<IconButton>(byKey('chat-send-button')).onPressed,
        isNull,
      );

      await tester.pump(const Duration(seconds: 8));
      expect(
        find.text('Sigo leyendo tu mensaje… a veces tarda unos segundos.'),
        findsOneWidget,
      );

      repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(byKey('chat-thinking'), findsNothing);
      expect(byKey('proposal-card'), findsOneWidget);
    },
  );

  testWidgets('the floating + stays and offers every way to add a movement', (
    tester,
  ) async {
    await pumpChat(tester, FakeTextCaptureRepository());

    expect(byKey('expenses-create-fab'), findsOneWidget);
    expect(byKey('expenses-wheel-manual'), findsNothing);

    await tester.tap(byKey('expenses-create-fab'));
    await tester.pumpAndSettle();
    expect(byKey('expenses-wheel-photo'), findsOneWidget);
    expect(byKey('expenses-wheel-voice'), findsOneWidget);
    expect(byKey('expenses-wheel-text'), findsOneWidget);
    expect(byKey('expenses-wheel-manual'), findsOneWidget);
    expect(find.text('Foto'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);

    await tester.tap(byKey('expenses-wheel-manual'));
    await tester.pumpAndSettle();

    expect(find.text('manual-form'), findsOneWidget);
  });

  testWidgets(
    'the wheel closes by tapping outside and its text option writes',
    (tester) async {
      await pumpChat(tester, FakeTextCaptureRepository());

      await tester.tap(byKey('expenses-create-fab'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('expenses-wheel-scrim'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(byKey('expenses-wheel-photo'), findsNothing);

      await tester.tap(byKey('expenses-create-fab'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('expenses-wheel-text'));
      await tester.pumpAndSettle();

      expect(byKey('expenses-wheel-photo'), findsNothing);
      final field = tester.widget<TextField>(byKey('chat-composer-field'));
      expect(field.focusNode!.hasFocus, isTrue);
    },
  );

  testWidgets('the voice option explains it is not available yet', (
    tester,
  ) async {
    await pumpChat(tester, FakeTextCaptureRepository());

    await tester.tap(byKey('expenses-create-fab'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('expenses-wheel-voice'));
    await tester.pump();

    expect(find.text('Captura por nota de voz próximamente'), findsOneWidget);
  });

  testWidgets('the floating + never hides the newest message', (tester) async {
    final repository = FakeTextCaptureRepository(
      proposals: List.generate(3, (_) => proposal(oneTap: false)),
    );
    await pumpChat(tester, repository, size: const Size(420, 600));
    for (var i = 0; i < 3; i++) {
      await send(tester, 'mensaje $i');
    }

    final fab = tester.getRect(byKey('expenses-create-fab'));
    final confirm = tester.getRect(byKey('proposal-confirm'));
    expect(confirm.bottom, lessThanOrEqualTo(fab.top + 1));
  });

  testWidgets('the recorded movement opens its detail', (tester) async {
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    await pumpChat(tester, repository);
    await send(tester, messageText);
    await tester.tap(byKey('proposal-confirm'));
    await tester.pumpAndSettle();

    await tester.tap(byKey('confirmed-view'));
    await tester.pumpAndSettle();

    expect(find.text('expense-701'), findsOneWidget);
  });

  testWidgets('works in the dark theme and with large text', (tester) async {
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    await pumpChat(
      tester,
      repository,
      theme: AppTheme.dark(),
      textScale: 1.6,
      size: const Size(360, 800),
    );

    await send(tester, messageText);

    expect(tester.takeException(), isNull);
    expect(byKey('proposal-confirm'), findsOneWidget);
    // Large text stacks the three actions instead of squeezing their labels.
    final confirm = tester.getTopLeft(byKey('proposal-confirm'));
    final edit = tester.getTopLeft(byKey('proposal-edit'));
    final discard = tester.getTopLeft(byKey('proposal-discard'));
    expect(edit.dy, greaterThan(confirm.dy));
    expect(discard.dy, greaterThan(edit.dy));
  });

  testWidgets('meets tap target and labelled control guidelines', (
    tester,
  ) async {
    final repository = FakeTextCaptureRepository(
      proposals: [proposal(), accountQuestion()],
    );
    await pumpChat(tester, repository);
    await send(tester, messageText);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('screen readers hear the new messages', (tester) async {
    final handle = tester.ensureSemantics();
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    await pumpChat(tester, repository);
    await send(tester, messageText);

    expect(find.bySemanticsLabel(RegExp('^Tú: ')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Asistente: ')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Propuesta de gasto')),
      findsOneWidget,
    );
    expect(find.byTooltip('Enviar mensaje'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a long conversation scrolls to the newest message', (
    tester,
  ) async {
    final repository = FakeTextCaptureRepository(
      proposals: List.generate(6, (_) => proposal(oneTap: false)),
    );
    await pumpChat(tester, repository, size: const Size(420, 600));

    for (var i = 0; i < 4; i++) {
      await send(tester, 'mensaje $i');
    }

    final list = tester.widget<ListView>(byKey('chat-messages'));
    final position = list.controller!.position;
    expect(position.pixels, closeTo(position.maxScrollExtent, 1));
    expect(find.text('mensaje 3'), findsOneWidget);
  });

  test('the conversation reset drops the open proposal', () async {
    final container = ProviderContainer(
      overrides: baseOverrides(repository: FakeTextCaptureRepository()),
    );
    addTearDown(container.dispose);

    expect(container.read(textCaptureControllerProvider).entries, hasLength(1));
  });
}
