import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login/presentation/login_screen.dart';
import '../../features/auth/register/presentation/register_screen.dart';
import '../../features/auth/session/application/auth_session_state.dart';
import '../../features/auth/session/presentation/session_bootstrap_screen.dart';
import '../../features/home/presentation/home_screen.dart';

GoRouter createAppRouter({
  String initialLocation = '/register',
  AuthSessionState Function()? authState,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: authState == null
        ? null
        : (context, routeState) {
            final session = authState();
            final location = routeState.uri.path;
            if (session.status == AuthSessionStatus.checking ||
                session.status == AuthSessionStatus.restorationRetry) {
              return location == '/bootstrap' ? null : '/bootstrap';
            }
            if (session.isAuthenticated) {
              return location == '/home' ? null : '/home';
            }
            if (location == '/home' || location == '/bootstrap') {
              return '/login';
            }
            return null;
          },
    routes: [
      GoRoute(
        path: '/bootstrap',
        name: 'bootstrap',
        builder: (context, state) => const SessionBootstrapScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) {
          final confirmation = state.extra is String
              ? state.extra! as String
              : null;
          return LoginScreen(registrationConfirmation: confirmation);
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
}
