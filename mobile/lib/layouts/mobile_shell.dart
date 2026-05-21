import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/money_visibility_provider.dart';
import '../router/route_names.dart';
import 'sidebar_widget.dart';

class MobileShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MobileShell({super.key, required this.navigationShell});

  static const _bottomItems = [
    NavItem(
      label: AppStrings.dashboard,
      icon: Icons.dashboard_rounded,
      iconColor: AppColors.iconDashboard,
      routeName: RouteNames.dashboard,
      requiredPermissions: ['dashboard:view'],
    ),
    NavItem(
      label: AppStrings.sales,
      icon: Icons.shopping_cart_rounded,
      iconColor: AppColors.iconSales,
      routeName: RouteNames.sales,
      requiredPermissions: ['sales:view', 'sales:manage'],
    ),
    NavItem(
      label: AppStrings.customers,
      icon: Icons.people_rounded,
      iconColor: AppColors.iconCustomers,
      routeName: RouteNames.customers,
      requiredPermissions: ['customers:view', 'customers:manage'],
    ),
    NavItem(
      label: AppStrings.inventory,
      icon: Icons.inventory_2_rounded,
      iconColor: AppColors.iconInventory,
      routeName: RouteNames.inventory,
      requiredPermissions: ['inventory:view', 'inventory:manage'],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final pageTitle = _titleFor(location);

    final visibleBottom = _bottomItems
        .where((i) =>
            i.requiredPermissions.isEmpty ||
            i.requiredPermissions.any((p) => auth.hasPermission(p)))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(pageTitle,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          Consumer(builder: (_, ref, __) {
            final visible = ref.watch(moneyVisibleProvider);
            return IconButton(
              icon: Icon(visible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
                  size: 20),
              tooltip: visible ? 'Hide amounts' : 'Show amounts',
              onPressed: () => ref
                  .read(moneyVisibleProvider.notifier)
                  .state = !visible,
            );
          }),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      drawer: _buildDrawer(context, ref, auth, location),
      body: navigationShell,
      bottomNavigationBar: Builder(
        builder: (scaffoldCtx) => BottomNavigationBar(
        currentIndex: _bottomIndex(location, visibleBottom),
        onTap: (i) {
          if (i < visibleBottom.length) {
            context.goNamed(visibleBottom[i].routeName);
          } else {
            Scaffold.of(scaffoldCtx).openDrawer();
          }
        },
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: [
          ...visibleBottom.map((item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.label,
              )),
          const BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz_rounded),
            label: AppStrings.more,
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref,
      AuthState auth, String location) {
    return Drawer(
      backgroundColor: AppColors.primary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: const SidebarWidget(),
    );
  }

  int _bottomIndex(String location, List<NavItem> items) {
    const pathMap = {
      RouteNames.dashboard: '/dashboard',
      RouteNames.sales: '/sales',
      RouteNames.customers: '/customers',
      RouteNames.inventory: '/inventory',
    };
    final idx = items.indexWhere(
        (i) => location == (pathMap[i.routeName] ?? ''));
    return idx < 0 ? items.length : idx;
  }

  String _titleFor(String location) {
    const map = {
      '/dashboard': AppStrings.dashboard,
      '/accounts': AppStrings.accounts,
      '/receipts': AppStrings.receipts,
      '/payments': AppStrings.payments,
      '/sales': AppStrings.sales,
      '/purchases': AppStrings.purchases,
      '/customers': AppStrings.customers,
      '/suppliers': AppStrings.suppliers,
      '/inventory': AppStrings.inventory,
      '/users': AppStrings.users,
      '/roles': AppStrings.roles,
      '/businesses': AppStrings.businesses,
      '/reports': AppStrings.reports,
      '/audit': AppStrings.audit,
      '/profile': 'Profile',
      '/settings': 'Settings',
    };
    return map[location] ?? AppStrings.appName;
  }
}
