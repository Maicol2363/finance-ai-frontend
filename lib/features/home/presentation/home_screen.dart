import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/manage_widgets.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/application/auth_session_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final state = ref.watch(authSessionControllerProvider);
    final controller = ref.read(authSessionControllerProvider.notifier);
    final user = state.user;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'Inicio',
                subtitle: 'Tu dinero, más claro',
                actions: [
                  const ThemeToggleButton(),
                  IconButton(
                    key: const Key('logout-button'),
                    tooltip: 'Cerrar sesión',
                    onPressed: state.status == AuthSessionStatus.loggingOut
                        ? null
                        : controller.logout,
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: palette.primarySoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tu sesión está activa',
                                key: const Key('home-title'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: palette.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                user == null
                                    ? 'Cuenta autenticada'
                                    : '${user.email} · ${user.preferredCurrency}',
                                key: const Key('home-user-context'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SectionTitle('Catálogos'),
                        SettingsGroup(
                          children: [
                            ManageRow(
                              rowKey: const Key('home-categories-button'),
                              title: 'Categorías',
                              subtitle: 'Clasifica tus gastos',
                              icon: Icons.category_outlined,
                              trailing: const [
                                Icon(Icons.chevron_right, size: 18),
                              ],
                              onTap: () => context.go('/categories'),
                            ),
                            ManageRow(
                              rowKey: const Key('open-income-sources-button'),
                              title: 'Fuentes de ingreso',
                              subtitle: 'Nombra de dónde viene tu dinero',
                              icon: Icons.savings_outlined,
                              trailing: const [
                                Icon(Icons.chevron_right, size: 18),
                              ],
                              onTap: () => context.push('/income-sources'),
                            ),
                          ],
                        ),
                        const SectionTitle('Mi cuenta'),
                        SettingsGroup(
                          children: [
                            ManageRow(
                              rowKey: const Key('home-accounts-button'),
                              title: 'Cuentas y saldos',
                              subtitle: 'Dónde está tu dinero',
                              icon: Icons.account_balance_wallet_outlined,
                              trailing: const [
                                Icon(Icons.chevron_right, size: 18),
                              ],
                              onTap: () => context.go('/accounts'),
                            ),
                            ManageRow(
                              rowKey: const Key('home-expenses-button'),
                              title: 'Gastos',
                              subtitle:
                                  'Consulta, corrige y elimina tus gastos',
                              icon: Icons.receipt_long_outlined,
                              trailing: const [
                                Icon(Icons.chevron_right, size: 18),
                              ],
                              onTap: () => context.go('/expenses'),
                            ),
                            ManageRow(
                              rowKey: const Key('home-history-button'),
                              title: 'Historial',
                              subtitle: 'Gastos, ingresos y transferencias',
                              icon: Icons.history_outlined,
                              trailing: const [
                                Icon(Icons.chevron_right, size: 18),
                              ],
                              onTap: () => context.go('/history'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Los formularios de presupuesto llegarán en las próximas historias. Funcionarán primero de forma manual; la asistencia opcional con IA usará los mismos formularios.',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.muted,
                            height: 1.45,
                          ),
                        ),
                        if (state.status == AuthSessionStatus.loggingOut) ...[
                          const SizedBox(height: 24),
                          Semantics(
                            liveRegion: true,
                            label: 'Cerrando sesión',
                            child: const LinearProgressIndicator(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
