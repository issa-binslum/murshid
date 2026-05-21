import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Permission catalogue — what each key controls
// ─────────────────────────────────────────────────────────────────────────────

const _sections = [
  _Section(
    label: 'Dashboard',
    icon: Icons.dashboard_rounded,
    color: AppColors.iconDashboard,
    items: [
      _PermDef('dashboard:view', 'View the dashboard',
          'See the main dashboard — stats, monthly revenue chart, invoice status and recent activity.'),
    ],
  ),
  _Section(
    label: 'Accounts',
    icon: Icons.account_balance_wallet_rounded,
    color: AppColors.iconAccounts,
    items: [
      _PermDef('accounts:view', 'View accounts',
          'Read-only access to bank, cash and mobile-wallet account balances.'),
      _PermDef('accounts:manage', 'Manage accounts',
          'Create, edit and delete accounts. Includes everything in accounts:view.'),
    ],
  ),
  _Section(
    label: 'Sales',
    icon: Icons.shopping_cart_rounded,
    color: AppColors.iconSales,
    items: [
      _PermDef('sales:view', 'View sales',
          'Read-only access to sales orders and sales invoices — list and detail pages.'),
      _PermDef('sales:manage', 'Manage sales',
          'Create, edit and cancel sales orders and invoices, update status and generate PDFs. Includes sales:view.'),
    ],
  ),
  _Section(
    label: 'Customers',
    icon: Icons.people_rounded,
    color: AppColors.iconCustomers,
    items: [
      _PermDef('customers:view', 'View customers',
          'Read-only access to the customer list and customer detail pages.'),
      _PermDef('customers:manage', 'Manage customers',
          'Add, edit and delete customer profiles. Includes customers:view.'),
    ],
  ),
  _Section(
    label: 'Purchases',
    icon: Icons.local_shipping_rounded,
    color: AppColors.iconPurchases,
    items: [
      _PermDef('purchases:view', 'View purchases',
          'Read-only access to purchase orders and purchase invoices — list and detail pages.'),
      _PermDef('purchases:manage', 'Manage purchases',
          'Create, edit and cancel purchase orders and invoices, update status and generate PDFs. Includes purchases:view.'),
    ],
  ),
  _Section(
    label: 'Suppliers',
    icon: Icons.store_rounded,
    color: AppColors.iconSuppliers,
    items: [
      _PermDef('suppliers:view', 'View suppliers',
          'Read-only access to the supplier list and supplier detail pages.'),
      _PermDef('suppliers:manage', 'Manage suppliers',
          'Add, edit and delete supplier profiles. Includes suppliers:view.'),
    ],
  ),
  _Section(
    label: 'Inventory',
    icon: Icons.inventory_2_rounded,
    color: AppColors.iconInventory,
    items: [
      _PermDef('inventory:view', 'View inventory',
          'Read-only access to the inventory list — item codes, names, units and stock levels.'),
      _PermDef('inventory:manage', 'Manage inventory',
          'Add, edit and delete items, adjust stock quantities and view movements. Includes inventory:view.'),
    ],
  ),
  _Section(
    label: 'Receipts',
    icon: Icons.receipt_long_rounded,
    color: AppColors.iconReceipts,
    items: [
      _PermDef('receipts:view', 'View receipts',
          'Read-only access to the receipts list and receipt detail pages.'),
      _PermDef('receipts:manage', 'Record receipts',
          'Create and delete incoming payment receipts linked to sales invoices. Includes receipts:view.'),
    ],
  ),
  _Section(
    label: 'Payments',
    icon: Icons.credit_card_rounded,
    color: AppColors.iconPayments,
    items: [
      _PermDef('payments:view', 'View payments',
          'Read-only access to the payments list and payment detail pages.'),
      _PermDef('payments:manage', 'Record payments',
          'Create and delete outgoing payments linked to purchase invoices. Includes payments:view.'),
    ],
  ),
  _Section(
    label: 'Reports',
    icon: Icons.bar_chart_rounded,
    color: AppColors.iconReports,
    items: [
      _PermDef('reports:view', 'View reports',
          'Access business reports, summaries and data exports.'),
    ],
  ),
  _Section(
    label: 'Users & Access',
    icon: Icons.manage_accounts_rounded,
    color: AppColors.iconUsers,
    items: [
      _PermDef('users:manage', 'Add & manage users',
          'Invite users, set their permissions, deactivate accounts and view the permissions reference.'),
    ],
  ),
  _Section(
    label: 'Audit Log',
    icon: Icons.history_rounded,
    color: AppColors.iconAudit,
    items: [
      _PermDef('audit:view', 'View audit log',
          'Read the full activity history — who created, edited or cancelled records and when.'),
    ],
  ),
  _Section(
    label: 'Super Admin',
    icon: Icons.business_rounded,
    color: AppColors.iconBusinesses,
    items: [
      _PermDef('business:create', 'Create businesses',
          'Create and manage multiple business workspaces. Granted to system-level admins only.'),
    ],
  ),
];

class _Section {
  final String label;
  final IconData icon;
  final Color color;
  final List<_PermDef> items;
  const _Section({
    required this.label,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class _PermDef {
  final String key;
  final String title;
  final String description;
  const _PermDef(this.key, this.title, this.description);
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class RolesScreen extends StatelessWidget {
  const RolesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 720;
    final isCompact = size.height < 500;

    return Scaffold(
      resizeToAvoidBottomInset: !isCompact,
      backgroundColor: AppColors.pageBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWide ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permissions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Reference guide — what each permission key allows in this system.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Info banner
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.navActiveBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'To assign permissions to a user, go to Users → select a user → Edit.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            // Permission sections
            ..._sections.map((section) => _SectionCard(
                  section: section,
                  isWide: isWide,
                )),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section card
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final _Section section;
  final bool isWide;
  const _SectionCard({required this.section, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: section.color.withAlpha(26),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(section.icon, size: 17, color: section.color),
                ),
                const SizedBox(width: 10),
                Text(
                  section.label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Permission rows
          ...section.items.asMap().entries.map((e) {
            final isLast = e.key == section.items.length - 1;
            return _PermRow(def: e.value, isLast: isLast, isWide: isWide);
          }),
        ],
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  final _PermDef def;
  final bool isLast;
  final bool isWide;
  const _PermRow({required this.def, required this.isLast, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Key chip
                SizedBox(
                  width: 200,
                  child: _KeyChip(key_: def.key),
                ),
                const SizedBox(width: 16),
                // Title + description
                Expanded(
                  child: _PermText(title: def.title, description: def.description),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KeyChip(key_: def.key),
                const SizedBox(height: 8),
                _PermText(title: def.title, description: def.description),
              ],
            ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  final String key_;
  const _KeyChip({required this.key_});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        key_,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _PermText extends StatelessWidget {
  final String title;
  final String description;
  const _PermText({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 3),
        Text(
          description,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
        ),
      ],
    );
  }
}
