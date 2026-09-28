import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/accounts/application/accounts_controller.dart';
import 'features/auth/session/application/auth_session_controller.dart';
import 'features/auth/session/application/auth_session_state.dart';
import 'features/categories/application/categories_controller.dart';
import 'features/expenses/application/expenses_controller.dart';
import 'features/expenses/application/history_controller.dart';
import 'features/income_sources/presentation/income_sources_controller.dart';
import 'features/incomes/data/incomes_repository.dart';
import 'features/receipt_capture/application/receipt_capture_notifier.dart';

class FinanceApp extends ConsumerStatefulWidget {
  const FinanceApp({super.key, this.router});

  final GoRouter? router;

  @override
  ConsumerState<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends ConsumerState<FinanceApp> {
  late final GoRouter _router;
  _RouterRefresh? _routerRefresh;
  ProviderSubscription<AuthSessionState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    ref.read(themeControllerProvider.notifier).load();
    ref.read(authSessionControllerProvider);

    void clearUserData() {
      ref.invalidate(accountsControllerProvider);
      ref.invalidate(categoriesControllerProvider);
      ref.invalidate(expensesControllerProvider);
      ref.invalidate(historyControllerProvider);
      ref.invalidate(incomesListProvider);
      ref.invalidate(incomeRevisionProvider);
      ref.invalidate(incomeSourcesControllerProvider);
      ref.invalidate(receiptCaptureNotifierProvider);
    }

    _authSubscription = ref.listenManual<AuthSessionState>(
      authSessionControllerProvider,
      (previous, next) {
        final userChanged = previous?.user?.id != next.user?.id;
        final unauthenticated =
            next.status == AuthSessionStatus.unauthenticated;
        if (userChanged || unauthenticated) {
          clearUserData();
        }
        _routerRefresh?.notifyRouter();
      },
    );

    final providedRouter = widget.router;
    if (providedRouter != null) {
      _router = providedRouter;
      return;
    }
    final routerRefresh = _RouterRefresh();
    _routerRefresh = routerRefresh;
    _router = createAppRouter(
      initialLocation: '/bootstrap',
      authState: () => ref.read(authSessionControllerProvider),
      refreshListenable: routerRefresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Finance AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeControllerProvider),
      routerConfig: _router,
    );
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _routerRefresh?.dispose();
    if (widget.router == null) {
      _router.dispose();
    }
    super.dispose();
  }
}

class _RouterRefresh extends ChangeNotifier {
  void notifyRouter() => notifyListeners();
}
