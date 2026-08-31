import 'dart:async';

import 'package:finance_ai/app.dart';
import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/features/auth/register/data/auth_repository.dart';
import 'package:finance_ai/features/auth/register/domain/registration_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class WidgetTestRepository implements AuthRepository {
  WidgetTestRepository({this.failure, this.pending});

  final RegistrationFailure? failure;
  final Completer<RegistrationResult>? pending;
  final requests = <RegistrationRequest>[];

  @override
  Future<RegistrationResult> register(RegistrationRequest request) async {
    requests.add(request);
    if (failure case final value?) {
      throw value;
    }
    if (pending case final value?) {
      return value.future;
    }
    return const RegistrationResult(
      user: RegisteredUser(
        id: 42,
        email: 'person@example.com',
        preferredCurrency: 'COP',
      ),
      message: 'Account created successfully. You can now log in.',
    );
  }
}

Future<GoRouter> pumpRegistration(
  WidgetTester tester,
  WidgetTestRepository repository,
) async {
  final router = createAppRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: FinanceApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> enterValidRegistration(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('register-email-input')),
    'person@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('register-password-input')),
    'valid password',
  );
  await tester.enterText(
    find.byKey(const Key('register-password-confirmation-input')),
    'valid password',
  );
}

void main() {
  testWidgets('renders the stable automation controls and accessible toggles', (
    tester,
  ) async {
    final router = await pumpRegistration(tester, WidgetTestRepository());
    addTearDown(router.dispose);

    expect(find.byKey(const Key('register-email-input')), findsOneWidget);
    expect(find.byKey(const Key('register-password-input')), findsOneWidget);
    expect(
      find.byKey(const Key('register-password-confirmation-input')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('register-submit-button')), findsOneWidget);
    expect(find.byTooltip('Show password'), findsOneWidget);
    expect(find.byTooltip('Show password confirmation'), findsOneWidget);

    TextField passwordField = tester.widget(
      find.byKey(const Key('register-password-input')),
    );
    expect(passwordField.obscureText, isTrue);
    await tester.tap(
      find.byKey(const Key('register-password-visibility-button')),
    );
    await tester.pump();
    passwordField = tester.widget(
      find.byKey(const Key('register-password-input')),
    );
    expect(passwordField.obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('shows all local guidance without sending a request', (
    tester,
  ) async {
    final repository = WidgetTestRepository();
    final router = await pumpRegistration(tester, repository);
    addTearDown(router.dispose);

    await tester.tap(find.byKey(const Key('register-submit-button')));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('register-password-confirmation-input')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Password confirmation is required.'), findsOneWidget);
    expect(repository.requests, isEmpty);
  });

  testWidgets(
    'disables Register and suppresses repeated taps during submission',
    (tester) async {
      final pending = Completer<RegistrationResult>();
      final repository = WidgetTestRepository(pending: pending);
      final router = await pumpRegistration(tester, repository);
      addTearDown(router.dispose);
      await enterValidRegistration(tester);

      await tester.tap(find.byKey(const Key('register-submit-button')));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('register-submit-button')),
      );
      expect(button.onPressed, isNull);
      expect(find.bySemanticsLabel('Creating account'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('register-submit-button')),
        warnIfMissed: false,
      );
      expect(repository.requests, hasLength(1));

      pending.complete(
        const RegistrationResult(
          user: RegisteredUser(
            id: 42,
            email: 'person@example.com',
            preferredCurrency: 'COP',
          ),
          message: 'Account created successfully. You can now log in.',
        ),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('maps server field errors without losing the email', (
    tester,
  ) async {
    final repository = WidgetTestRepository(
      failure: const RegistrationValidationFailure(
        userMessage: 'Correct the highlighted fields.',
        fieldErrors: {
          'password': ['Choose a safer password.'],
        },
      ),
    );
    final router = await pumpRegistration(tester, repository);
    addTearDown(router.dispose);
    await enterValidRegistration(tester);

    await tester.tap(find.byKey(const Key('register-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Choose a safer password.'), findsOneWidget);
    final emailField = tester.widget<TextField>(
      find.byKey(const Key('register-email-input')),
    );
    expect(emailField.controller?.text, 'person@example.com');
    expect(find.byKey(const Key('register-success-message')), findsNothing);
  });

  testWidgets('maps duplicate conflict to the email field', (tester) async {
    final repository = WidgetTestRepository(
      failure: const RegistrationConflictFailure(
        userMessage: 'This email is already registered.',
      ),
    );
    final router = await pumpRegistration(tester, repository);
    addTearDown(router.dispose);
    await enterValidRegistration(tester);

    await tester.tap(find.byKey(const Key('register-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('This email is already registered.'), findsWidgets);
    final emailField = tester.widget<TextField>(
      find.byKey(const Key('register-email-input')),
    );
    expect(emailField.focusNode?.hasPrimaryFocus, isTrue);
  });

  testWidgets('shows safe retry feedback and leaves the form available', (
    tester,
  ) async {
    final platformCalls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final repository = WidgetTestRepository(
      failure: const RegistrationRetryableFailure(
        code: 'service_unavailable',
        userMessage:
            'Registration is temporarily unavailable. Please try again later.',
        correlationId: 'safe-server-correlation',
        technicalReason: 'http_503',
      ),
    );
    final router = await pumpRegistration(tester, repository);
    addTearDown(router.dispose);
    await enterValidRegistration(tester);

    await tester.tap(find.byKey(const Key('register-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('register-error-banner')), findsOneWidget);
    expect(find.textContaining('temporarily unavailable'), findsOneWidget);
    expect(find.text('Error code: service_unavailable'), findsOneWidget);
    expect(find.byKey(const Key('copy-error-details-button')), findsOneWidget);
    final emailField = tester.widget<TextField>(
      find.byKey(const Key('register-email-input')),
    );
    expect(emailField.enabled, isTrue);

    await tester.tap(find.byKey(const Key('copy-error-details-button')));
    await tester.pump();

    final clipboardCall = platformCalls.singleWhere(
      (call) => call.method == 'Clipboard.setData',
    );
    final copied =
        (clipboardCall.arguments as Map<Object?, Object?>)['text']! as String;
    expect(copied, contains('Error code: service_unavailable'));
    expect(copied, contains('Request/correlation ID: safe-server-correlation'));
    expect(copied, contains('Technical reason: http_503'));
    expect(copied, isNot(contains('person@example.com')));
    expect(copied, isNot(contains('valid password')));
    expect(find.text('Safe error details copied.'), findsOneWidget);
  });

  testWidgets('success clears the form route and navigates once to Login', (
    tester,
  ) async {
    final repository = WidgetTestRepository();
    final router = await pumpRegistration(tester, repository);
    addTearDown(router.dispose);
    await enterValidRegistration(tester);

    await tester.tap(find.byKey(const Key('register-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('register-success-message')), findsOneWidget);
    expect(find.textContaining('Manual entry works'), findsOneWidget);
    expect(find.byKey(const Key('register-password-input')), findsNothing);
    expect(repository.requests, hasLength(1));
  });
}
