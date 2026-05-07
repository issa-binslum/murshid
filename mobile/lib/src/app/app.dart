import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../features/accounts/accounts_screen.dart';
import '../features/customers/customers_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/payments/payments_screen.dart';
import '../features/receipts/receipts_screen.dart';
import '../features/suppliers/suppliers_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/pick_business_screen.dart';
import '../core/theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final ValueNotifier<AuthState> _authStateNotifier;
  late final GoRouter _router;
  bool _didSetupListener = false;

  @override
  void initState() {
    super.initState();
    _authStateNotifier = ValueNotifier(ref.read(authControllerProvider));

    _router = GoRouter(
      initialLocation: '/login',
      refreshListenable: _authStateNotifier,
      redirect: (context, state) {
        final authState = _authStateNotifier.value;
        print(
            'Redirect check: isLoggedIn=${authState.isLoggedIn}, accessToken=${authState.accessToken != null}, location=${state.matchedLocation}');
        final isLoggingIn = state.matchedLocation == '/login';
        final isPickingBusiness = state.matchedLocation == '/pick-business';

        if (!authState.isLoggedIn) {
          print('Redirecting to /login');
          return isLoggingIn ? null : '/login';
        }

        if (authState.accessToken == null) {
          print('Redirecting to /pick-business');
          return isPickingBusiness ? null : '/pick-business';
        }

        if (isLoggingIn || isPickingBusiness) {
          print('Authenticated user redirecting to /');
          return '/';
        }

        print('No redirect');
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginScreen(),
        ),
        GoRoute(
          path: '/pick-business',
          builder: (context, state) => PickBusinessScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => DashboardScreen(),
        ),
        GoRoute(
          path: '/accounts',
          builder: (context, state) => AccountsScreen(),
        ),
        GoRoute(
          path: '/customers',
          builder: (context, state) => CustomersScreen(),
        ),
        GoRoute(
          path: '/suppliers',
          builder: (context, state) => SuppliersScreen(),
        ),
        GoRoute(
          path: '/inventory',
          builder: (context, state) => InventoryScreen(),
        ),
        GoRoute(
          path: '/receipts',
          builder: (context, state) => ReceiptsScreen(),
        ),
        GoRoute(
          path: '/payments',
          builder: (context, state) => PaymentsScreen(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _authStateNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_didSetupListener) {
      ref.listen<AuthState>(authControllerProvider, (_, next) {
        print(
            'Auth state changed: isLoggedIn=${next.isLoggedIn}, accessToken=${next.accessToken != null}');
        _authStateNotifier.value = next;
      });
      _didSetupListener = true;
    }

    final lightScheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Issa Wholesale',
      theme: buildAppTheme(lightScheme),
      darkTheme: buildAppTheme(darkScheme),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
