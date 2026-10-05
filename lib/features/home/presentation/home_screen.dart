import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/application/accounts_state.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/application/auth_session_state.dart';
import '../../categories/application/categories_controller.dart';
import '../../categories/application/categories_state.dart';
import '../../text_capture/presentation/text_capture_chat.dart';

/// Gastos tab: the capture chat comes first.
///
/// The user writes what happened and the assistant prepares the operation for
/// a quick review. Balance and recent movements live in the Dashboard; the
/// manual forms stay one tap away in the composer's menu.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // The review card offers these lists when the user edits a proposal.
    Future<void>.microtask(() {
      if (!mounted) return;
      if (ref.read(accountsControllerProvider).listStatus ==
          AccountsLoadStatus.initial) {
        ref.read(accountsControllerProvider.notifier).load();
      }
      if (ref.read(categoriesControllerProvider).loadStatus ==
          CategoriesLoadStatus.initial) {
        ref.read(categoriesControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sessionState = ref.watch(authSessionControllerProvider);
    final sessionController = ref.read(authSessionControllerProvider.notifier);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gastos', key: Key('home-title')),
              Text(
                'cuéntame qué pasó — la IA lo prepara y tú confirmas',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: palette.muted,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              key: const Key('home-search-button'),
              tooltip: 'Buscar en historial',
              onPressed: () => context.push('/history'),
              icon: const Icon(Icons.search),
            ),
            const ThemeToggleButton(),
            IconButton(
              key: const Key('logout-button'),
              tooltip: 'Cerrar sesión',
              onPressed: sessionState.status == AuthSessionStatus.loggingOut
                  ? null
                  : sessionController.logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: const SafeArea(child: TextCaptureChat()),
      ),
    );
  }
}
