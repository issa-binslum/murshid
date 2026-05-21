import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/money_visibility_provider.dart';
import '../router/route_names.dart';
import 'sidebar_widget.dart';

class DesktopShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const DesktopShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Row(
        children: [
          const SidebarWidget(),
          Expanded(
            child: Column(
              children: [
                _TopBar(auth: auth, location: location),
                Expanded(child: navigationShell),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  final AuthState auth;
  final String location;

  const _TopBar({required this.auth, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = _initials(auth.user?.fullName ?? '?');

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // ── Left: breadcrumb ──────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.home_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                _pageTitle(location),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // ── Center: search bar ────────────────────────────────────
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText:
                          'Search transactions, customers, reports...',
                      hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: AppColors.textSecondary),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                      filled: true,
                      fillColor: AppColors.pageBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Right: eye + bell + user ─────────────────────────────
          Row(
            children: [
              // Money visibility toggle
              Consumer(builder: (_, ref, __) {
                final visible = ref.watch(moneyVisibleProvider);
                return IconButton(
                  icon: Icon(
                    visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: visible
                        ? AppColors.textSecondary
                        : AppColors.primary,
                  ),
                  tooltip:
                      visible ? 'Hide amounts' : 'Show amounts',
                  onPressed: () => ref
                      .read(moneyVisibleProvider.notifier)
                      .state = !visible,
                  splashRadius: 20,
                );
              }),
              const SizedBox(width: 4),
              // Notification bell with badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        size: 22, color: AppColors.textSecondary),
                    onPressed: () {},
                    splashRadius: 20,
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.cardRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const VerticalDivider(
                  width: 1, thickness: 1, color: AppColors.border),
              const SizedBox(width: 12),

              // User avatar + name + role — dropdown menu
              _UserMenu(auth: auth, initials: initials),
            ],
          ),
        ],
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

  String _pageTitle(String location) {
    const map = {
      '/dashboard': 'Dashboard',
      '/accounts': 'Accounts',
      '/receipts': 'Receipts',
      '/payments': 'Payments',
      '/sales': 'Sales',
      '/purchases': 'Purchases',
      '/customers': 'Customers',
      '/suppliers': 'Suppliers',
      '/inventory': 'Inventory',
      '/users': 'Users',
      '/roles': 'Roles',
      '/businesses': 'Businesses',
      '/reports': 'Reports',
      '/audit': 'Audit Log',
      '/profile': 'Profile',
      '/settings': 'Settings',
      '/no-access': '',
    };
    return map[location] ?? '';
  }
}

// ── User dropdown menu ────────────────────────────────────────────────────────

enum _UserMenuAction { profile, settings, logout }

class _UserMenu extends ConsumerWidget {
  final AuthState auth;
  final String initials;

  const _UserMenu({required this.auth, required this.initials});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_UserMenuAction>(
      offset: const Offset(0, 44),
      color: AppColors.cardBackground,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      onSelected: (action) {
        if (action == _UserMenuAction.profile) {
          context.go(RoutePaths.profile);
        } else if (action == _UserMenuAction.settings) {
          context.go(RoutePaths.settings);
        } else {
          _showLogout(context, ref);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<_UserMenuAction>(
          value: _UserMenuAction.profile,
          child: Row(
            children: const [
              Icon(Icons.manage_accounts_outlined,
                  size: 18, color: AppColors.textSecondary),
              SizedBox(width: 10),
              Text(
                'Profile',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        PopupMenuItem<_UserMenuAction>(
          value: _UserMenuAction.settings,
          child: Row(
            children: const [
              Icon(Icons.settings_outlined,
                  size: 18, color: AppColors.textSecondary),
              SizedBox(width: 10),
              Text(
                'Settings',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<_UserMenuAction>(
          value: _UserMenuAction.logout,
          child: Row(
            children: const [
              Icon(Icons.logout_rounded, size: 18, color: AppColors.dangerText),
              SizedBox(width: 10),
              Text(
                'Sign Out',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.dangerText,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryDark,
              child: Text(
                initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.user?.fullName ?? '',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                Text(
                  auth.currentBusiness?.isOwner == true ? 'Owner' : 'Member',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
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
