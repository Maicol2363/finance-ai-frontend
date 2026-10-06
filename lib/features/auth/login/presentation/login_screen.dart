import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/auth_brand.dart';
import '../../../../core/widgets/manage_widgets.dart';
import '../../../../core/widgets/theme_toggle_button.dart';
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
    final palette = context.palette;
    final state = ref.watch(authSessionControllerProvider);
    final controller = ref.read(authSessionControllerProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthBrand(),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: palette.card,
                          border: Border.all(color: palette.line),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Bienvenido de nuevo',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: palette.text,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Accede para ver tus gastos, ingresos y cuentas.',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.muted,
                                height: 1.45,
                              ),
                            ),
                            if (widget.registrationConfirmation
                                case final message?) ...[
                              const SizedBox(height: 12),
                              Container(
                                key: const Key('register-success-message'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.incomeSoft,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.income,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                            if (state.logoutWarning case final warning?) ...[
                              const SizedBox(height: 12),
                              ErrorDiagnosticPanel(
                                key: const Key('logout-warning-banner'),
                                diagnostic: warning,
                              ),
                            ],
                            if (state.diagnostic case final diagnostic?) ...[
                              const SizedBox(height: 12),
                              ErrorDiagnosticPanel(
                                key: const Key('login-error-banner'),
                                diagnostic: diagnostic,
                              ),
                            ],
                            const FieldLabel(
                              'Correo electrónico',
                              uppercase: false,
                            ),
                            TextField(
                              key: const Key('login-email-input'),
                              controller: _emailController,
                              focusNode: _emailFocus,
                              enabled: !state.isBusy,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: pillInputDecoration(
                                context,
                                hint: 'tu@correo.com',
                                prefixIcon: Icon(
                                  Icons.mail_outline,
                                  size: 18,
                                  color: palette.muted,
                                ),
                                errorText: _firstError(state, 'email'),
                              ),
                              onChanged: (_) =>
                                  controller.clearFieldError('email'),
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                            ),
                            const FieldLabel('Contraseña', uppercase: false),
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
                              decoration: pillInputDecoration(
                                context,
                                hint: 'Tu contraseña',
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  size: 18,
                                  color: palette.muted,
                                ),
                                errorText: _firstError(state, 'password'),
                                suffixIcon: IconButton(
                                  key: const Key(
                                    'login-password-visibility-button',
                                  ),
                                  tooltip: _showPassword
                                      ? 'Ocultar contraseña'
                                      : 'Mostrar contraseña',
                                  onPressed: state.isBusy
                                      ? null
                                      : () => setState(
                                          () => _showPassword = !_showPassword,
                                        ),
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 18,
                                  ),
                                ),
                              ),
                              onChanged: (_) =>
                                  controller.clearFieldError('password'),
                              onSubmitted: (_) {
                                if (!state.isBusy) {
                                  _submit();
                                }
                              },
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
                              key: const Key('login-submit-button'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: state.isBusy ? null : _submit,
                              child:
                                  state.status == AuthSessionStatus.submitting
                                  ? Semantics(
                                      liveRegion: true,
                                      label: 'Iniciando sesión',
                                      child: SizedBox.square(
                                        dimension: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: palette.onPrimary,
                                        ),
                                      ),
                                    )
                                  : const Text('Iniciar sesión'),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton(
                                key: const Key('login-create-account-button'),
                                onPressed: state.isBusy
                                    ? null
                                    : () => context.go('/register'),
                                child: const Text(
                                  '¿No tienes una cuenta? Crear una cuenta',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(top: 4, right: 6, child: ThemeToggleButton()),
          ],
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
