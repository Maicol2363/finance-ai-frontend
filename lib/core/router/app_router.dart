import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login/presentation/login_screen.dart';
import '../../features/auth/register/presentation/register_screen.dart';
import '../../features/auth/session/application/auth_session_state.dart';
import '../../features/auth/session/presentation/session_bootstrap_screen.dart';
import '../../features/accounts/presentation/account_detail_screen.dart';
import '../../features/accounts/presentation/account_form_screen.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/income_sources/presentation/income_sources_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/categories/presentation/category_form_screen.dart';

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
              final authenticatedDestination =
                  location == '/home' ||
                  location.startsWith('/accounts') ||
                  location.startsWith('/categories') ||
                  location == '/income-sources';
              return authenticatedDestination ? null : '/home';
            }
            if (location == '/home' ||
                location.startsWith('/accounts') ||
                location.startsWith('/categories') ||
                location == '/income-sources' ||
                location == '/bootstrap') {
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
      GoRoute(
        path: '/income-sources',
        name: 'incomeSources',
        builder: (context, state) => const IncomeSourcesScreen(),
      ),
      GoRoute(
        path: '/categories',
        name: 'categories',
        builder: (context, state) => const CategoriesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'category-new',
            builder: (context, state) => const CategoryFormScreen(),
          ),
          GoRoute(
            path: ':categoryId/edit',
            name: 'category-edit',
            builder: (context, state) => CategoryFormScreen(
              categoryId:
                  int.tryParse(state.pathParameters['categoryId'] ?? '') ?? 0,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/accounts',
        name: 'accounts',
        builder: (context, state) => const AccountsScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'account-new',
            builder: (context, state) => const AccountFormScreen(),
          ),
          GoRoute(
            path: ':accountId',
            name: 'account-detail',
            builder: (context, state) => AccountDetailScreen(
              accountId:
                  int.tryParse(state.pathParameters['accountId'] ?? '') ?? 0,
            ),
            routes: [
              GoRoute(
                path: 'edit',
                name: 'account-edit',
                builder: (context, state) => AccountFormScreen(
                  accountId:
                      int.tryParse(state.pathParameters['accountId'] ?? '') ??
                      0,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
