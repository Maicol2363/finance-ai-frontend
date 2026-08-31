import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/diagnostics/error_diagnostic_panel.dart';
import 'registration_controller.dart';
import 'registration_state.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmationFocus = FocusNode();
  bool _showPassword = false;
  bool _showConfirmation = false;

  @override
  void dispose() {
    _passwordController.clear();
    _confirmationController.clear();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmationFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationControllerProvider);
    final controller = ref.read(registrationControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        actions: [
          TextButton(
            onPressed: state.isSubmitting ? null : () => context.go('/login'),
            child: const Text('Login'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              children: [
                Text(
                  'Start your budget',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your account now. You can enter everything manually; optional assistance comes later.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                if (state.diagnostic case final diagnostic?) ...[
                  ErrorDiagnosticPanel(
                    key: const Key('register-error-banner'),
                    diagnostic: diagnostic,
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(
                  key: const Key('register-email-input'),
                  controller: _emailController,
                  focusNode: _emailFocus,
                  enabled: !state.isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                    errorText: _firstError(state, 'email'),
                  ),
                  onChanged: (_) => controller.clearFieldError('email'),
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('register-password-input'),
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  enabled: !state.isSubmitting,
                  obscureText: !_showPassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: 'Use 8–128 characters.',
                    errorText: _firstError(state, 'password'),
                    suffixIcon: IconButton(
                      key: const Key('register-password-visibility-button'),
                      tooltip: _showPassword
                          ? 'Hide password'
                          : 'Show password',
                      onPressed: state.isSubmitting
                          ? null
                          : () =>
                                setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  onChanged: (_) => controller.clearFieldError('password'),
                  onSubmitted: (_) => _confirmationFocus.requestFocus(),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('register-password-confirmation-input'),
                  controller: _confirmationController,
                  focusNode: _confirmationFocus,
                  enabled: !state.isSubmitting,
                  obscureText: !_showConfirmation,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    errorText: _firstError(state, 'password_confirmation'),
                    suffixIcon: IconButton(
                      key: const Key('register-confirmation-visibility-button'),
                      tooltip: _showConfirmation
                          ? 'Hide password confirmation'
                          : 'Show password confirmation',
                      onPressed: state.isSubmitting
                          ? null
                          : () => setState(
                              () => _showConfirmation = !_showConfirmation,
                            ),
                      icon: Icon(
                        _showConfirmation
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  onChanged: (_) =>
                      controller.clearFieldError('password_confirmation'),
                  onSubmitted: (_) {
                    if (!state.isSubmitting) {
                      _submit();
                    }
                  },
                ),
                const SizedBox(height: 28),
                FilledButton(
                  key: const Key('register-submit-button'),
                  onPressed: state.isSubmitting ? null : _submit,
                  child: state.isSubmitting
                      ? Semantics(
                          liveRegion: true,
                          label: 'Creating account',
                          child: SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : const Text('Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _firstError(RegistrationState state, String field) {
    final errors = state.fieldErrors[field];
    return errors == null || errors.isEmpty ? null : errors.first;
  }

  Future<void> _submit() async {
    final outcome = await ref
        .read(registrationControllerProvider.notifier)
        .submit(
          email: _emailController.text,
          password: _passwordController.text,
          passwordConfirmation: _confirmationController.text,
        );
    if (!mounted) {
      return;
    }
    final state = ref.read(registrationControllerProvider);
    if (outcome == RegistrationSubmitOutcome.success) {
      final message = state.result?.message ?? 'Account created successfully.';
      _passwordController.clear();
      _confirmationController.clear();
      context.go('/login', extra: message);
      return;
    }
    if (outcome == RegistrationSubmitOutcome.invalid ||
        outcome == RegistrationSubmitOutcome.failure) {
      _focusFirstError(state);
    }
  }

  void _focusFirstError(RegistrationState state) {
    if (state.fieldErrors.containsKey('email')) {
      _emailFocus.requestFocus();
    } else if (state.fieldErrors.containsKey('password')) {
      _passwordFocus.requestFocus();
    } else if (state.fieldErrors.containsKey('password_confirmation')) {
      _confirmationFocus.requestFocus();
    }
  }
}
