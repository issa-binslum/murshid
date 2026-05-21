import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/sidebar_provider.dart';
import '../router/route_names.dart';
import 'business_switcher_widget.dart';

class NavItem {
  final String label;
  final IconData icon;
  final Color iconColor;
  final String routeName;
  /// User needs ANY ONE of these permissions to see this item.
  final List<String> requiredPermissions;
  final bool requiresBusiness;

  const NavItem({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.routeName,
    this.requiredPermissions = const [],
    this.requiresBusiness = true,
  });
}

class NavSection {
  final String? label;
  final List<NavItem> items;
  const NavSection({this.label, required this.items});
}

final _navSections = [
  NavSection(items: [
    NavItem(
      label: AppStrings.dashboard,
      icon: Icons.dashboard_rounded,
      iconColor: AppColors.iconDashboard,
      routeName: RouteNames.dashboard,
      requiredPermissions: ['dashboard:view'],
      requiresBusiness: false,
    ),
  ]),
  NavSection(label: AppStrings.sectionSetup, items: [
    NavItem(
      label: AppStrings.businesses,
      icon: Icons.business_rounded,
      iconColor: AppColors.iconBusinesses,
      routeName: RouteNames.businesses,
      requiredPermissions: ['business:create'],
      requiresBusiness: false,
    ),
  ]),
  NavSection(label: AppStrings.sectionFinancials, items: [
    NavItem(
      label: AppStrings.accounts,
      icon: Icons.account_balance_wallet_rounded,
      iconColor: AppColors.iconAccounts,
      routeName: RouteNames.accounts,
      requiredPermissions: ['accounts:view', 'accounts:manage'],
    ),
    NavItem(
      label: AppStrings.receipts,
      icon: Icons.receipt_long_rounded,
      iconColor: AppColors.iconReceipts,
      routeName: RouteNames.receipts,
      requiredPermissions: ['receipts:view', 'receipts:manage'],
    ),
    NavItem(
      label: AppStrings.payments,
      icon: Icons.credit_card_rounded,
      iconColor: AppColors.iconPayments,
      routeName: RouteNames.payments,
      requiredPermissions: ['payments:view', 'payments:manage'],
    ),
  ]),
  NavSection(label: AppStrings.sectionTrade, items: [
    NavItem(
      label: AppStrings.sales,
      icon: Icons.shopping_cart_rounded,
      iconColor: AppColors.iconSales,
      routeName: RouteNames.sales,
      requiredPermissions: ['sales:view', 'sales:manage'],
    ),
    NavItem(
      label: AppStrings.purchases,
      icon: Icons.local_shipping_rounded,
      iconColor: AppColors.iconPurchases,
      routeName: RouteNames.purchases,
      requiredPermissions: ['purchases:view', 'purchases:manage'],
    ),
  ]),
  NavSection(label: AppStrings.sectionContacts, items: [
    NavItem(
      label: AppStrings.customers,
      icon: Icons.people_rounded,
      iconColor: AppColors.iconCustomers,
      routeName: RouteNames.customers,
      requiredPermissions: ['customers:view', 'customers:manage'],
    ),
    NavItem(
      label: AppStrings.suppliers,
      icon: Icons.store_rounded,
      iconColor: AppColors.iconSuppliers,
      routeName: RouteNames.suppliers,
      requiredPermissions: ['suppliers:view', 'suppliers:manage'],
    ),
  ]),
  NavSection(label: AppStrings.sectionStock, items: [
    NavItem(
      label: AppStrings.inventory,
      icon: Icons.inventory_2_rounded,
      iconColor: AppColors.iconInventory,
      routeName: RouteNames.inventory,
      requiredPermissions: ['inventory:view', 'inventory:manage'],
    ),
  ]),
  NavSection(label: AppStrings.sectionSettings, items: [
    NavItem(
      label: AppStrings.users,
      icon: Icons.manage_accounts_rounded,
      iconColor: AppColors.iconUsers,
      routeName: RouteNames.users,
      requiredPermissions: ['users:manage'],
    ),
    NavItem(
      label: AppStrings.roles,
      icon: Icons.admin_panel_settings_rounded,
      iconColor: AppColors.iconRoles,
      routeName: RouteNames.roles,
      requiredPermissions: ['users:manage'],
    ),
    NavItem(
      label: AppStrings.audit,
      icon: Icons.history_rounded,
      iconColor: AppColors.iconAudit,
      routeName: RouteNames.audit,
      requiredPermissions: ['audit:view', 'users:manage'],
    ),
  ]),
  NavSection(items: [
    NavItem(
      label: AppStrings.reports,
      icon: Icons.bar_chart_rounded,
      iconColor: AppColors.iconReports,
      routeName: RouteNames.reports,
      requiredPermissions: ['reports:view'],
    ),
  ]),
];

const double _expandedWidth = 240;
const double _collapsedWidth = 64;

class SidebarWidget extends ConsumerWidget {
  const SidebarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final location = GoRouterState.of(context).matchedLocation;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: collapsed ? _collapsedWidth : _expandedWidth,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBackground,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Brand / business switcher ───────────────────────────────
          SafeArea(
            bottom: false,
            child: collapsed
                ? _CollapsedBrand(auth: auth)
                : BusinessSwitcherWidget(),
          ),

          // ── Collapse toggle ─────────────────────────────────────────
          _CollapseButton(collapsed: collapsed, ref: ref),

          const Divider(height: 1, color: AppColors.border),

          // ── Nav items ───────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Banner when no business is active
                if (auth.currentBusiness == null && !collapsed)
                  _NoBusiness(),
                ..._navSections.expand((section) {
                  final visible = section.items.where((item) {
                    if (item.requiredPermissions.isEmpty) return true;
                    return item.requiredPermissions
                        .any((p) => auth.hasPermission(p));
                  }).toList();

                  if (visible.isEmpty) return <Widget>[];

                  return [
                    if (section.label != null) const SizedBox(height: 4),
                    ...visible.map((item) => _NavTile(
                          item: item,
                          isActive: location == _pathFor(item.routeName),
                          collapsed: collapsed,
                          locked: item.requiresBusiness &&
                              auth.currentBusiness == null,
                        )),
                  ];
                }),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // ── User footer ─────────────────────────────────────────────
          _UserTile(auth: auth, collapsed: collapsed),
        ],
      ),
    );
  }

  String _pathFor(String routeName) {
    const map = {
      RouteNames.dashboard: '/dashboard',
      RouteNames.accounts: '/accounts',
      RouteNames.receipts: '/receipts',
      RouteNames.payments: '/payments',
      RouteNames.sales: '/sales',
      RouteNames.purchases: '/purchases',
      RouteNames.customers: '/customers',
      RouteNames.suppliers: '/suppliers',
      RouteNames.inventory: '/inventory',
      RouteNames.users: '/users',
      RouteNames.roles: '/roles',
      RouteNames.businesses: '/businesses',
      RouteNames.reports: '/reports',
      RouteNames.audit: '/audit',
      RouteNames.noAccess: '/no-access',
    };
    return map[routeName] ?? '';
  }
}

// ── Brand when collapsed (icon only) ─────────────────────────────────────────

class _CollapsedBrand extends StatelessWidget {
  final AuthState auth;
  const _CollapsedBrand({required this.auth});

  @override
  Widget build(BuildContext context) {
    final name = auth.currentBusiness?.name ?? 'B';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'B',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

// ── Collapse toggle button ─────────────────────────────────────────────────────

class _CollapseButton extends StatelessWidget {
  final bool collapsed;
  final WidgetRef ref;
  const _CollapseButton({required this.collapsed, required this.ref});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          ref.read(sidebarCollapsedProvider.notifier).update((s) => !s),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              collapsed
                  ? Icons.chevron_right_rounded
                  : Icons.chevron_left_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            if (!collapsed) ...[
              const SizedBox(width: 6),
              const Text(
                'Collapse',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── No-business banner ────────────────────────────────────────────────────────

class _NoBusiness extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warningText.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warningText.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 14, color: AppColors.warningText),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'No active business.\nGo to Businesses to create or select one.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.warningText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav tile ─────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool isActive;
  final bool collapsed;
  final bool locked;

  const _NavTile({
    required this.item,
    required this.isActive,
    required this.collapsed,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectivelyLocked = locked && !isActive;
    final iconColor = effectivelyLocked
        ? AppColors.textSecondary.withAlpha(100)
        : isActive
            ? AppColors.navActiveBorder
            : item.iconColor;

    final tooltipMsg = effectivelyLocked
        ? 'Select a business first'
        : collapsed
            ? item.label
            : '';

    return Tooltip(
      message: tooltipMsg,
      preferBelow: false,
      child: Opacity(
        opacity: effectivelyLocked ? 0.45 : 1.0,
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: collapsed ? 8 : 8, vertical: 1),
          child: Material(
            color: isActive ? AppColors.navActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: effectivelyLocked ? null : () => context.goNamed(item.routeName),
              child: Container(
                decoration: isActive
                    ? BoxDecoration(
                        border: Border(
                          left: BorderSide(
                              color: AppColors.navActiveBorder, width: 3),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                padding: EdgeInsets.only(
                  left: isActive ? (collapsed ? 9 : 9) : (collapsed ? 12 : 12),
                  right: 12,
                  top: 9,
                  bottom: 9,
                ),
                child: Row(
                  children: [
                    Icon(item.icon, size: 20, color: iconColor),
                    if (!collapsed) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? AppColors.navActiveText
                                : AppColors.navInactiveText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── User footer ───────────────────────────────────────────────────────────────

class _UserTile extends ConsumerWidget {
  final AuthState auth;
  final bool collapsed;
  const _UserTile({required this.auth, required this.collapsed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = _initials(auth.user?.fullName ?? '?');

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: GestureDetector(
            onTap: () => _showLogout(context, ref),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryDark,
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showLogout(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryDark,
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    auth.user?.fullName ?? '',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Administrator',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_vert_rounded,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _showLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.sidebarBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sign Out',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You\'ll be signed out and returned to the login screen.',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ref.read(authProvider.notifier).logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dangerText,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Sign Out',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
