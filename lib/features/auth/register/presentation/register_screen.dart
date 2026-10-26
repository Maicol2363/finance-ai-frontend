import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/auth_brand.dart';
import '../../../../core/widgets/manage_widgets.dart';
import '../../../../core/widgets/theme_toggle_button.dart';
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
    final palette = context.palette;
    final state = ref.watch(registrationControllerProvider);
    final controller = ref.read(registrationControllerProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Crear cuenta',
              leading: HeaderIconButton(
                icon: FinanceIcons.arrowBack,
                tooltip: 'Volver',
                onPressed: state.isSubmitting
                    ? null
                    : () => context.go('/login'),
              ),
              actions: const [ThemeToggleButton()],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthBrand(showTitle: false),
                        const SizedBox(height: 12),
                        if (state.diagnostic case final diagnostic?) ...[
                          ErrorDiagnosticPanel(
                            key: const Key('register-error-banner'),
                            diagnostic: diagnostic,
                          ),
                          const SizedBox(height: 12),
                        ],
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
                                'Crea tu cuenta para empezar a organizar tus finanzas.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.muted,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                key: const Key('register-email-input'),
                                controller: _emailController,
                                focusNode: _emailFocus,
                                enabled: !state.isSubmitting,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                autocorrect: false,
                                decoration: pillInputDecoration(
                                  context,
                                  hint: 'tu@correo.com',
                                  labelText: 'Correo electrónico',
                                  errorText: _firstError(state, 'email'),
                                ),
                                onChanged: (_) =>
                                    controller.clearFieldError('email'),
                                onSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                key: const Key('register-password-input'),
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                enabled: !state.isSubmitting,
                                obscureText: !_showPassword,
                                enableSuggestions: false,
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                decoration: pillInputDecoration(
                                  context,
                                  hint: 'Mínimo 8 caracteres',
                                  labelText: 'Contraseña',
                                  errorText: _firstError(state, 'password'),
                                  suffixIcon: IconButton(
                                    key: const Key(
                                      'register-password-visibility-button',
                                    ),
                                    tooltip: _showPassword
                                        ? 'Ocultar contraseña'
                                        : 'Mostrar contraseña',
                                    onPressed: state.isSubmitting
                                        ? null
                                        : () => setState(
                                            () =>
                                                _showPassword = !_showPassword,
                                          ),
                                    icon: Icon(
                                      _showPassword
                                          ? FinanceIcons.visibilityOff
                                          : FinanceIcons.visibility,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                onChanged: (_) =>
                                    controller.clearFieldError('password'),
                                onSubmitted: (_) =>
                                    _confirmationFocus.requestFocus(),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                key: const Key(
                                  'register-password-confirmation-input',
                                ),
                                controller: _confirmationController,
                                focusNode: _confirmationFocus,
                                enabled: !state.isSubmitting,
                                obscureText: !_showConfirmation,
                                enableSuggestions: false,
                                autocorrect: false,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                decoration: pillInputDecoration(
                                  context,
                                  hint: 'Repite tu contraseña',
                                  labelText: 'Confirmar contraseña',
                                  errorText: _firstError(
                                    state,
                                    'password_confirmation',
                                  ),
                                  suffixIcon: IconButton(
                                    key: const Key(
                                      'register-confirmation-visibility-button',
                                    ),
                                    tooltip: _showConfirmation
                                        ? 'Ocultar confirmación'
                                        : 'Mostrar confirmación',
                                    onPressed: state.isSubmitting
                                        ? null
                                        : () => setState(
                                            () => _showConfirmation =
                                                !_showConfirmation,
                                          ),
                                    icon: Icon(
                                      _showConfirmation
                                          ? FinanceIcons.visibilityOff
                                          : FinanceIcons.visibility,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                onChanged: (_) => controller.clearFieldError(
                                  'password_confirmation',
                                ),
                                onSubmitted: (_) {
                                  if (!state.isSubmitting) {
                                    _submit();
                                  }
                                },
                              ),
                              const SizedBox(height: 18),
                              FilledButton(
                                key: const Key('register-submit-button'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                onPressed: state.isSubmitting ? null : _submit,
                                child: state.isSubmitting
                                    ? Semantics(
                                        liveRegion: true,
                                        label: 'Creando cuenta',
                                        child: SizedBox.square(
                                          dimension: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: palette.onPrimary,
                                          ),
                                        ),
                                      )
                                    : const Text('Crear cuenta'),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton(
                                  key: const Key('register-to-login-button'),
                                  onPressed: state.isSubmitting
                                      ? null
                                      : () => context.go('/login'),
                                  child: const Text('Ya tengo una cuenta'),
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
            ),
          ],
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
    if (outcome == RegistrationSubmitOutcome.success) {
      _passwordController.clear();
      _confirmationController.clear();
      // The API message is not presentation copy and may be in another
      // language. Keep the confirmation localized and independent of it.
      context.go(
        '/login',
        extra: 'Tu cuenta se creó correctamente. Ya puedes iniciar sesión.',
      );
      return;
    }
    final state = ref.read(registrationControllerProvider);
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
