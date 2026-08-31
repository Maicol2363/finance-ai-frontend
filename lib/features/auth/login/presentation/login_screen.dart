import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../session/application/auth_session_controller.dart';
import '../../session/application/auth_session_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.registrationConfirmation});

  final String? registrationConfirmation;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _showPassword = false;

  @override
  void dispose() {
    _passwordController.clear();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authSessionControllerProvider);
    final controller = ref.read(authSessionControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        actions: [
          TextButton(
            key: const Key('login-create-account-button'),
            onPressed: state.isBusy ? null : () => context.go('/register'),
            child: const Text('Create account'),
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
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Log in to continue to your budget. Manual entry works without optional AI assistance.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (widget.registrationConfirmation case final message?) ...[
                  const SizedBox(height: 24),
                  Material(
                    key: const Key('register-success-message'),
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(message),
                    ),
                  ),
                ],
                if (state.logoutWarning case final warning?) ...[
                  const SizedBox(height: 20),
                  ErrorDiagnosticPanel(
                    key: const Key('logout-warning-banner'),
                    diagnostic: warning,
                  ),
                ],
                if (state.diagnostic case final diagnostic?) ...[
                  const SizedBox(height: 20),
                  ErrorDiagnosticPanel(
                    key: const Key('login-error-banner'),
                    diagnostic: diagnostic,
                  ),
                ],
                const SizedBox(height: 28),
                TextField(
                  key: const Key('login-email-input'),
                  controller: _emailController,
                  focusNode: _emailFocus,
                  enabled: !state.isBusy,
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
                  key: const Key('login-password-input'),
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  enabled: !state.isBusy,
                  obscureText: !_showPassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorText: _firstError(state, 'password'),
                    suffixIcon: IconButton(
                      key: const Key('login-password-visibility-button'),
                      tooltip: _showPassword
                          ? 'Hide password'
                          : 'Show password',
                      onPressed: state.isBusy
                          ? null
                          : () =>
                                setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  onChanged: (_) => controller.clearFieldError('password'),
                  onSubmitted: (_) {
                    if (!state.isBusy) {
                      _submit();
                    }
                  },
                ),
                const SizedBox(height: 28),
                FilledButton(
                  key: const Key('login-submit-button'),
                  onPressed: state.isBusy ? null : _submit,
                  child: state.status == AuthSessionStatus.submitting
                      ? Semantics(
                          liveRegion: true,
                          label: 'Logging in',
                          child: const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _firstError(AuthSessionState state, String field) {
    final errors = state.fieldErrors[field];
    return errors == null || errors.isEmpty ? null : errors.first;
  }

  Future<void> _submit() async {
    final outcome = await ref
        .read(authSessionControllerProvider.notifier)
        .login(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) {
      return;
    }
    _passwordController.clear();
    if (outcome == LoginSubmitOutcome.invalid ||
        outcome == LoginSubmitOutcome.failure) {
      final state = ref.read(authSessionControllerProvider);
      if (state.fieldErrors.containsKey('email')) {
        _emailFocus.requestFocus();
      } else if (state.fieldErrors.containsKey('password')) {
        _passwordFocus.requestFocus();
      }
    }
  }
}
