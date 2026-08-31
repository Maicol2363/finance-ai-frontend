import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/session/application/auth_session_controller.dart';
import 'features/auth/session/application/auth_session_state.dart';

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
    final providedRouter = widget.router;
    if (providedRouter != null) {
      _router = providedRouter;
      return;
    }
    ref.read(authSessionControllerProvider);
    final routerRefresh = _RouterRefresh();
    _routerRefresh = routerRefresh;
    _authSubscription = ref.listenManual<AuthSessionState>(
      authSessionControllerProvider,
      (previous, next) => routerRefresh.notifyRouter(),
    );
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
