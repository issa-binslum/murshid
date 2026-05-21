import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/audit_model.dart';
import '../../core/providers/audit_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Static option lists
// ─────────────────────────────────────────────────────────────────────────────

const _entityOptions = [
  ('Customer', 'Customer'),
  ('Supplier', 'Supplier'),
  ('InventoryItem', 'Inventory Item'),
  ('SalesInvoice', 'Sales Invoice'),
  ('PurchaseInvoice', 'Purchase Invoice'),
  ('Payment', 'Payment'),
  ('Receipt', 'Receipt'),
  ('User', 'User'),
  ('Business', 'Business'),
];

const _actionOptions = [
  ('create', 'Created'),
  ('edit', 'Updated'),
  ('delete', 'Deleted'),
  ('cancel', 'Cancelled'),
  ('mark_paid', 'Marked Paid'),
  ('invite', 'Invited'),
  ('deactivate', 'Deactivated'),
];

const _periodOptions = [
  ('today', 'Today'),
  ('yesterday', 'Yesterday'),
  ('week', 'Last 7 days'),
  ('month', 'Last 30 days'),
  ('this_month', 'This month'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _fmtEntity(String raw) => raw
    .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(0)}')
    .trim();

String _fmtAction(String raw) => switch (raw) {
      'create' => 'Created',
      'edit' => 'Updated',
      'cancel' => 'Cancelled',
      'delete' => 'Deleted',
      'mark_paid' => 'Marked Paid',
      'invite' => 'Invited',
      'deactivate' => 'Deactivated',
      _ => raw[0].toUpperCase() + raw.substring(1),
    };

(Color bg, Color fg) _actionStyle(String action) => switch (action) {
      'create' => (AppColors.successBg, AppColors.successText),
      'edit' => (AppColors.navActiveBg, AppColors.primary),
      'cancel' || 'delete' || 'deactivate' => (
          AppColors.dangerBg,
          AppColors.dangerText,
        ),
      'mark_paid' => (const Color(0xFFCCFBF1), const Color(0xFF0F766E)),
      'invite' => (const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
      _ => (AppColors.warningBg, AppColors.warningText),
    };

IconData _entityIcon(String entity) => switch (entity) {
      'SalesInvoice' || 'SalesOrder' => Icons.shopping_cart_rounded,
      'PurchaseInvoice' || 'PurchaseOrder' => Icons.local_shipping_rounded,
      'Customer' => Icons.people_rounded,
      'Supplier' => Icons.store_rounded,
      'InventoryItem' => Icons.inventory_2_rounded,
      'Payment' => Icons.credit_card_rounded,
      'Receipt' => Icons.receipt_long_rounded,
      'User' => Icons.manage_accounts_rounded,
      'Business' => Icons.business_rounded,
      _ => Icons.history_rounded,
    };

Color _entityColor(String entity) => switch (entity) {
      'SalesInvoice' || 'SalesOrder' => AppColors.iconSales,
      'PurchaseInvoice' || 'PurchaseOrder' => AppColors.iconPurchases,
      'Customer' => AppColors.iconCustomers,
      'Supplier' => AppColors.iconSuppliers,
      'InventoryItem' => AppColors.iconInventory,
      'Payment' => AppColors.iconPayments,
      'Receipt' => AppColors.iconReceipts,
      'User' => AppColors.iconUsers,
      'Business' => AppColors.iconBusinesses,
      _ => AppColors.textSecondary,
    };

String _fmtDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}

String _shortId(String? id) {
  if (id == null || id.length < 8) return id ?? '—';
  return '#${id.substring(id.length - 6).toUpperCase()}';
}

List<int?> _pageNumbers(int current, int total) {
  if (total <= 7) return List.generate(total, (i) => i + 1);
  final set = <int>{1, total};
  for (int i = current - 2; i <= current + 2; i++) {
    if (i >= 1 && i <= total) set.add(i);
  }
  final sorted = set.toList()..sort();
  final result = <int?>[];
  for (int i = 0; i < sorted.length; i++) {
    result.add(sorted[i]);
    if (i < sorted.length - 1 && sorted[i + 1] - sorted[i] > 1) {
      result.add(null);
    }
  }
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchSubmit(String value) {
    final current = ref.read(auditProvider).filters;
    ref
        .read(auditProvider.notifier)
        .applyFilters(current.copyWith(search: value.trim()));
  }

  void _setEntity(String? value) {
    final current = ref.read(auditProvider).filters;
    ref
        .read(auditProvider.notifier)
        .applyFilters(current.copyWith(entity: value));
  }

  void _setAction(String? value) {
    final current = ref.read(auditProvider).filters;
    ref
        .read(auditProvider.notifier)
        .applyFilters(current.copyWith(action: value));
  }

  void _setPeriod(String? value) {
    final current = ref.read(auditProvider).filters;
    ref
        .read(auditProvider.notifier)
        .applyFilters(current.copyWith(period: value));
  }

  void _clearAll() {
    _searchCtrl.clear();
    ref.read(auditProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context, ) {
    final state = ref.watch(auditProvider);
    final notifier = ref.read(auditProvider.notifier);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Padding(
        padding: EdgeInsets.all(isWide ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            _PageHeader(
              total: state.total,
              isLoading: state.isLoading,
              onRefresh: notifier.load,
            ),
            const SizedBox(height: 16),

            // ── Search bar ────────────────────────────────────────────
            TextField(
              controller: _searchCtrl,
              onSubmitted: _onSearchSubmit,
              decoration: InputDecoration(
                hintText: 'Search by entity type, user or reference ID…',
                hintStyle: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: AppColors.textSecondary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 16, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchSubmit('');
                        },
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                        const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                        const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 8),

            // ── Filter row ────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Entity
                  _DropFilter<String>(
                    label: 'Entity',
                    value: state.filters.entity,
                    displayText: state.filters.entity != null
                        ? _fmtEntity(state.filters.entity!)
                        : null,
                    items: _entityOptions
                        .map((e) => (e.$1, e.$2))
                        .toList(),
                    onSelected: _setEntity,
                    onClear: () => _setEntity(null),
                  ),
                  const SizedBox(width: 8),

                  // Action
                  _DropFilter<String>(
                    label: 'Action',
                    value: state.filters.action,
                    displayText: state.filters.action != null
                        ? _fmtAction(state.filters.action!)
                        : null,
                    items: _actionOptions
                        .map((e) => (e.$1, e.$2))
                        .toList(),
                    onSelected: _setAction,
                    onClear: () => _setAction(null),
                  ),
                  const SizedBox(width: 8),

                  // Period
                  _DropFilter<String>(
                    label: 'Period',
                    value: state.filters.period,
                    displayText: state.filters.period != null
                        ? _periodOptions
                            .firstWhere(
                                (e) => e.$1 == state.filters.period)
                            .$2
                        : null,
                    items: _periodOptions
                        .map((e) => (e.$1, e.$2))
                        .toList(),
                    onSelected: _setPeriod,
                    onClear: () => _setPeriod(null),
                  ),

                  // Clear all (only when any filter active)
                  if (state.filters.isActive) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      height: 20,
                      child: VerticalDivider(
                          width: 1, color: AppColors.border),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _clearAll,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.close_rounded,
                                size: 14, color: AppColors.dangerText),
                            const SizedBox(width: 4),
                            Text(
                              'Clear all'
                              ' (${state.filters.activeCount})',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.dangerText,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Error ─────────────────────────────────────────────────
            if (state.error != null)
              _ErrorBanner(message: state.error!, onRetry: notifier.load),

            // ── Body ──────────────────────────────────────────────────
            if (state.isLoading && state.items.isEmpty)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary),
                ),
              )
            else if (state.items.isEmpty && !state.isLoading)
              _EmptyState(isFiltered: state.filters.isActive)
            else
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          isWide
                              ? _DesktopTable(entries: state.items)
                              : _MobileList(entries: state.items),
                          if (state.isLoading)
                            const Positioned.fill(
                              child: ColoredBox(
                                color: Color(0x55FFFFFF),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.primary),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PaginationBar(
                      currentPage: state.currentPage,
                      totalPages: state.totalPages,
                      total: state.total,
                      limit: state.limit,
                      isLoading: state.isLoading,
                      onPage: notifier.goToPage,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drop filter chip
// ─────────────────────────────────────────────────────────────────────────────

class _DropFilter<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String? displayText;
  final List<(T, String)> items;
  final void Function(T) onSelected;
  final VoidCallback onClear;

  const _DropFilter({
    required this.label,
    required this.value,
    required this.displayText,
    required this.items,
    required this.onSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value != null;

    return PopupMenuButton<T>(
      onSelected: onSelected,
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      itemBuilder: (_) => items
          .map((e) => PopupMenuItem<T>(
                value: e.$1,
                child: Row(
                  children: [
                    if (value == e.$1)
                      const Icon(Icons.check_rounded,
                          size: 14, color: AppColors.primary)
                    else
                      const SizedBox(width: 14),
                    const SizedBox(width: 8),
                    Text(e.$2,
                        style: TextStyle(
                            fontSize: 13,
                            color: value == e.$1
                                ? AppColors.primary
                                : AppColors.textPrimary)),
                  ],
                ),
              ))
          .toList(),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.navActiveBg : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isActive ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive ? displayText! : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            if (isActive)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 12, color: AppColors.primary),
              )
            else
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final int total;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _PageHeader({
    required this.total,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Audit Log',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Track every action performed in this business',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Tooltip(
          message: 'Refresh',
          child: IconButton(
            onPressed: isLoading ? null : onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: AppColors.textSecondary,
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop table
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopTable extends StatelessWidget {
  final List<AuditEntry> entries;
  const _DesktopTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFECEEF2),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 16),
                SizedBox(width: 44),
                _HeaderCell('Action', flex: 2),
                _HeaderCell('Entity', flex: 3),
                _HeaderCell('Reference', flex: 2),
                _HeaderCell('User', flex: 2),
                _HeaderCell('Time', flex: 2),
                SizedBox(width: 16),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) =>
                  _DesktopRow(entry: entries[i], index: i),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  const _HeaderCell(this.label, {this.flex = 1});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      );
}

class _DesktopRow extends StatelessWidget {
  final AuditEntry entry;
  final int index;
  const _DesktopRow({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    final (actionBg, actionFg) = _actionStyle(entry.action);
    final entityColor = _entityColor(entry.entity);
    final entityIcon = _entityIcon(entry.entity);
    final bg = index.isOdd ? const Color(0xFFF9FAFB) : Colors.white;

    return Material(
      color: bg,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: entityColor.withAlpha(26),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(entityIcon, size: 16, color: entityColor),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: actionBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _fmtAction(entry.action),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: actionFg),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _fmtEntity(entry.entity),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _shortId(entry.entityId),
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                entry.userName ?? entry.userUsername ?? 'System',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _fmtDate(entry.createdAt),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile list
// ─────────────────────────────────────────────────────────────────────────────

class _MobileList extends StatelessWidget {
  final List<AuditEntry> entries;
  const _MobileList({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, i) => _MobileRow(entry: entries[i]),
      ),
    );
  }
}

class _MobileRow extends StatelessWidget {
  final AuditEntry entry;
  const _MobileRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final (actionBg, actionFg) = _actionStyle(entry.action);
    final entityColor = _entityColor(entry.entity);
    final entityIcon = _entityIcon(entry.entity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: entityColor.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(entityIcon, size: 18, color: entityColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: actionBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _fmtAction(entry.action),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: actionFg),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _fmtEntity(entry.entity),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.userName ?? entry.userUsername ?? 'System'} · ${_fmtDate(entry.createdAt)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pagination bar
// ─────────────────────────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int total;
  final int limit;
  final bool isLoading;
  final void Function(int) onPage;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.total,
    required this.limit,
    required this.isLoading,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final first = (currentPage - 1) * limit + 1;
    final last = (currentPage * limit).clamp(1, total);
    final pages = _pageNumbers(currentPage, totalPages);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (isWide)
            Text(
              total == 0
                  ? '0 records'
                  : 'Showing $first–$last of $total records',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          const Spacer(),
          _NavBtn(
            label: 'Prev',
            icon: Icons.chevron_left_rounded,
            iconFirst: true,
            enabled: currentPage > 1 && !isLoading,
            onTap: () => onPage(currentPage - 1),
          ),
          const SizedBox(width: 4),
          ...pages.map((p) {
            if (p == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('…',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              );
            }
            final isCurrent = p == currentPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: (!isCurrent && !isLoading) ? () => onPage(p) : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        isCurrent ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isCurrent
                        ? null
                        : Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '$p',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color:
                          isCurrent ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 4),
          _NavBtn(
            label: 'Next',
            icon: Icons.chevron_right_rounded,
            iconFirst: false,
            enabled: currentPage < totalPages && !isLoading,
            onTap: () => onPage(currentPage + 1),
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool iconFirst;
  final bool enabled;
  final VoidCallback onTap;

  const _NavBtn({
    required this.label,
    required this.icon,
    required this.iconFirst,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        enabled ? AppColors.textPrimary : AppColors.textSecondary;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: iconFirst
              ? [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 2),
                  Text(label,
                      style: TextStyle(fontSize: 12, color: color)),
                ]
              : [
                  Text(label,
                      style: TextStyle(fontSize: 12, color: color)),
                  const SizedBox(width: 2),
                  Icon(icon, size: 16, color: color),
                ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / error states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isFiltered;
  const _EmptyState({required this.isFiltered});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFiltered
                  ? Icons.search_off_rounded
                  : Icons.history_rounded,
              size: 48,
              color: AppColors.border,
            ),
            const SizedBox(height: 12),
            Text(
              isFiltered ? 'No matching records' : 'No activity yet',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              isFiltered
                  ? 'Try adjusting your search or filters.'
                  : 'Actions in the system will appear here.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorBanner({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        border: Border.all(color: AppColors.dangerText.withAlpha(80)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.dangerText,
                    fontWeight: FontWeight.w500)),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.dangerText,
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
