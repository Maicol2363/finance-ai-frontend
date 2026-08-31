import 'dart:async';

import 'package:finance_ai/features/auth/register/data/auth_repository.dart';
import 'package:finance_ai/features/auth/register/domain/registration_models.dart';
import 'package:finance_ai/features/auth/register/presentation/registration_controller.dart';
import 'package:finance_ai/features/auth/register/presentation/registration_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.result, this.failure, this.pending});

  final RegistrationResult? result;
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
    return result ?? successfulResult;
  }
}

const successfulResult = RegistrationResult(
  user: RegisteredUser(
    id: 42,
    email: 'person@example.com',
    preferredCurrency: 'COP',
  ),
  message: 'Account created successfully. You can now log in.',
);

ProviderContainer containerFor(FakeAuthRepository repository) {
  return ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
  );
}

void main() {
  test(
    'local validation reports every field and does not call the API',
    () async {
      final repository = FakeAuthRepository();
      final container = containerFor(repository);
      addTearDown(container.dispose);

      final outcome = await container
          .read(registrationControllerProvider.notifier)
          .submit(
            email: 'bad',
            password: 'short',
            passwordConfirmation: 'different',
          );

      final state = container.read(registrationControllerProvider);
      expect(outcome, RegistrationSubmitOutcome.invalid);
      expect(
        state.fieldErrors.keys,
        containsAll(['email', 'password', 'password_confirmation']),
      );
      expect(state.diagnostic?.code, 'registration_invalid');
      expect(state.diagnostic?.technicalReason, 'client_validation');
      expect(repository.requests, isEmpty);
    },
  );

  test(
    'valid request trims email but preserves both secrets exactly',
    () async {
      final repository = FakeAuthRepository();
      final container = containerFor(repository);
      addTearDown(container.dispose);
      const password = '  exact password  ';

      final outcome = await container
          .read(registrationControllerProvider.notifier)
          .submit(
            email: '  Person@Example.com  ',
            password: password,
            passwordConfirmation: password,
          );

      expect(outcome, RegistrationSubmitOutcome.success);
      expect(repository.requests.single.email, 'Person@Example.com');
      expect(repository.requests.single.password, password);
      expect(repository.requests.single.passwordConfirmation, password);
      expect(
        container.read(registrationControllerProvider).result,
        successfulResult,
      );
    },
  );

  test('second submit is ignored while the first request is pending', () async {
    final pending = Completer<RegistrationResult>();
    final repository = FakeAuthRepository(pending: pending);
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(registrationControllerProvider.notifier);

    final first = controller.submit(
      email: 'person@example.com',
      password: 'valid password',
      passwordConfirmation: 'valid password',
    );
    final second = await controller.submit(
      email: 'person@example.com',
      password: 'valid password',
      passwordConfirmation: 'valid password',
    );

    expect(second, RegistrationSubmitOutcome.ignored);
    expect(repository.requests, hasLength(1));
    expect(container.read(registrationControllerProvider).isSubmitting, isTrue);
    pending.complete(successfulResult);
    expect(await first, RegistrationSubmitOutcome.success);
  });

  test(
    'server validation and conflict failures map to editable fields',
    () async {
      final validationRepository = FakeAuthRepository(
        failure: const RegistrationValidationFailure(
          userMessage: 'Correct the fields.',
          fieldErrors: {
            'password': ['Choose a safer password.'],
          },
        ),
      );
      final validationContainer = containerFor(validationRepository);
      addTearDown(validationContainer.dispose);

      await validationContainer
          .read(registrationControllerProvider.notifier)
          .submit(
            email: 'person@example.com',
            password: 'valid password',
            passwordConfirmation: 'valid password',
          );

      expect(
        validationContainer
            .read(registrationControllerProvider)
            .fieldErrors['password'],
        ['Choose a safer password.'],
      );

      final conflictRepository = FakeAuthRepository(
        failure: const RegistrationConflictFailure(
          userMessage: 'This email is already registered.',
        ),
      );
      final conflictContainer = containerFor(conflictRepository);
      addTearDown(conflictContainer.dispose);
      await conflictContainer
          .read(registrationControllerProvider.notifier)
          .submit(
            email: 'person@example.com',
            password: 'valid password',
            passwordConfirmation: 'valid password',
          );

      expect(
        conflictContainer
            .read(registrationControllerProvider)
            .fieldErrors['email'],
        ['This email is already registered.'],
      );
    },
  );

  test('retryable failure exposes only safe guidance and permits retry', () async {
    final repository = FakeAuthRepository(
      failure: const RegistrationRetryableFailure(
        code: 'service_unavailable',
        userMessage:
            'Registration is temporarily unavailable. Please try again later.',
      ),
    );
    final container = containerFor(repository);
    addTearDown(container.dispose);

    final outcome = await container
        .read(registrationControllerProvider.notifier)
        .submit(
          email: 'person@example.com',
          password: 'valid password',
          passwordConfirmation: 'valid password',
        );

    final state = container.read(registrationControllerProvider);
    expect(outcome, RegistrationSubmitOutcome.failure);
    expect(state.isSubmitting, isFalse);
    expect(state.generalError, contains('temporarily unavailable'));
    expect(state.diagnostic?.code, 'service_unavailable');
    expect(state.diagnostic?.operation, 'register_account');
    expect(
      state.diagnostic?.clipboardText,
      isNot(contains('person@example.com')),
    );
  });
}
