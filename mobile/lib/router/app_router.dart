import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/auth_provider.dart';
import '../features/accounts/accounts_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/pick_business_screen.dart';
import '../features/businesses/businesses_screen.dart';
import '../features/customers/customers_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/no_access/no_access_screen.dart';
import '../features/payments/payments_screen.dart';
import '../features/purchases/purchases_screen.dart';
import '../features/receipts/receipts_screen.dart';
import '../features/audit/audit_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/roles/roles_screen.dart';
import '../features/sales/sales_screen.dart';
import '../features/suppliers/suppliers_screen.dart';
import '../features/users/users_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../layouts/adaptive_shell.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}

// Maps each protected route to the permissions that grant access.
// ORDER MATTERS — _firstAccessibleRoute() walks this top to bottom.
// If the user has ANY one of the listed permissions, access is granted.
const _routePermissions = <String, List<String>>{
  '/dashboard':  ['dashboard:view'],
  '/accounts':   ['accounts:view', 'accounts:manage'],
  '/receipts':   ['receipts:manage'],
  '/payments':   ['payments:manage'],
  '/sales':      ['sales:manage'],
  '/purchases':  ['purchases:manage'],
  '/customers':  ['customers:manage'],
  '/suppliers':  ['suppliers:manage'],
  '/inventory':  ['inventory:manage'],
  '/users':      ['users:manage'],
  '/roles':      ['roles:manage'],
  '/businesses': ['business:create'],
  '/reports':    ['reports:view'],
  '/audit':      ['audit:view', 'users:manage'],
};

/// Returns the first route this user can access, or /no-access if none.
String _firstAccessibleRoute(AuthState auth) {
  for (final entry in _routePermissions.entries) {
    if (entry.value.any((p) => auth.hasPermission(p))) {
      return entry.key;
    }
  }
  return RoutePaths.noAccess;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RoutePaths.dashboard,
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;

      // ── Not authenticated ──────────────────────────────────────────
      if (!auth.isAuthenticated && !auth.needsBusinessSelection) {
        if (loc != RoutePaths.login) return RoutePaths.login;
        return null;
      }

      // ── Needs business selection ───────────────────────────────────
      if (auth.needsBusinessSelection) {
        if (loc != RoutePaths.pickBusiness) return RoutePaths.pickBusiness;
        return null;
      }

      // ── Fully authenticated: leave auth screens ────────────────────
      if (loc == RoutePaths.login || loc == RoutePaths.pickBusiness) {
        return _firstAccessibleRoute(auth);
      }

      // ── No-access page: re-check in case permissions changed ───────
      if (loc == RoutePaths.noAccess) {
        final first = _firstAccessibleRoute(auth);
        if (first != RoutePaths.noAccess) return first;
        return null;
      }

      // ── Permission guard for all other routes ──────────────────────
      final required = _routePermissions[loc];
      if (required != null) {
        final allowed = required.any((p) => auth.hasPermission(p));
        if (!allowed) return _firstAccessibleRoute(auth);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.pickBusiness,
        name: RouteNames.pickBusiness,
        builder: (_, __) => const PickBusinessScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AdaptiveShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKey,
            routes: [
              GoRoute(
                path: RoutePaths.dashboard,
                name: RouteNames.dashboard,
                builder: (_, __) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.accounts,
              name: RouteNames.accounts,
              builder: (_, __) => const AccountsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.receipts,
              name: RouteNames.receipts,
              builder: (_, __) => const ReceiptsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.payments,
              name: RouteNames.payments,
              builder: (_, __) => const PaymentsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.sales,
              name: RouteNames.sales,
              builder: (_, __) => const SalesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.purchases,
              name: RouteNames.purchases,
              builder: (_, __) => const PurchasesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.customers,
              name: RouteNames.customers,
              builder: (_, __) => const CustomersScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.suppliers,
              name: RouteNames.suppliers,
              builder: (_, __) => const SuppliersScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.inventory,
              name: RouteNames.inventory,
              builder: (_, __) => const InventoryScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.users,
              name: RouteNames.users,
              builder: (_, __) => const UsersScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.roles,
              name: RouteNames.roles,
              builder: (_, __) => const RolesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.businesses,
              name: RouteNames.businesses,
              builder: (_, __) => const BusinessesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.reports,
              name: RouteNames.reports,
              builder: (_, __) => const ReportsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.audit,
              name: RouteNames.audit,
              builder: (_, __) => const AuditScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.noAccess,
              name: RouteNames.noAccess,
              builder: (_, __) => const NoAccessScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.profile,
              name: RouteNames.profile,
              builder: (_, __) => const ProfileScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.settings,
              name: RouteNames.settings,
              builder: (_, __) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
