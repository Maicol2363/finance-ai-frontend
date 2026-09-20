import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/account_detail_screen.dart';
import '../../features/accounts/presentation/account_form_screen.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/auth/login/presentation/login_screen.dart';
import '../../features/auth/register/presentation/register_screen.dart';
import '../../features/auth/session/application/auth_session_state.dart';
import '../../features/auth/session/presentation/session_bootstrap_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/categories/presentation/category_form_screen.dart';
import '../../features/expenses/presentation/expense_create_screen.dart';
import '../../features/expenses/presentation/expense_detail_screen.dart';
import '../../features/expenses/presentation/expense_form_screen.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/expenses/presentation/history_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/income_sources/presentation/income_sources_screen.dart';
import '../../features/incomes/presentation/income_detail_screen.dart';
import '../../features/incomes/presentation/income_form_screen.dart';
import '../../features/incomes/presentation/income_list_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'app_shell.dart';

const _authenticatedRoots = <String>[
  '/home',
  '/settings',
  '/accounts',
  '/categories',
  '/expenses',
  '/history',
  '/income-sources',
  '/incomes',
];

bool _isProtected(String location) {
  if (location == '/bootstrap') {
    return true;
  }
  return _authenticatedRoots.any(
    (root) => location == root || location.startsWith('$root/'),
  );
}

GoRouter createAppRouter({
  String initialLocation = '/bootstrap',
  ValueGetter<AuthSessionState>? authState,
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
              if (location == '/bootstrap') {
                return '/home';
              }
              return _isProtected(location) ? null : '/home';
            }
            return _isProtected(location) ? '/login' : null;
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/income-sources',
        name: 'incomeSources',
        builder: (context, state) => const IncomeSourcesScreen(),
      ),
      GoRoute(
        path: '/incomes',
        name: 'incomes',
        builder: (context, state) => const IncomeListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'income-new',
            builder: (context, state) => const IncomeFormScreen(),
          ),
          GoRoute(
            path: ':incomeId',
            name: 'income-detail',
            builder: (context, state) => IncomeDetailScreen(
              incomeId:
                  int.tryParse(state.pathParameters['incomeId'] ?? '') ?? 0,
            ),
            routes: [
              GoRoute(
                path: 'edit',
                name: 'income-edit',
                builder: (context, state) => IncomeFormScreen(
                  incomeId:
                      int.tryParse(state.pathParameters['incomeId'] ?? '') ?? 0,
                ),
              ),
            ],
          ),
        ],
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
        path: '/expenses',
        name: 'expenses',
        builder: (context, state) => const ExpensesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'expense-new',
            builder: (context, state) => const ExpenseCreateScreen(),
          ),
          GoRoute(
            path: ':expenseId',
            name: 'expense-detail',
            builder: (context, state) => ExpenseDetailScreen(
              expenseId:
                  int.tryParse(state.pathParameters['expenseId'] ?? '') ?? 0,
            ),
            routes: [
              GoRoute(
                path: 'edit',
                name: 'expense-edit',
                builder: (context, state) => ExpenseFormScreen(
                  expenseId:
                      int.tryParse(state.pathParameters['expenseId'] ?? '') ??
                      0,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const HistoryScreen(),
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
