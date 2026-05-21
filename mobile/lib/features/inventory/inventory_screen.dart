import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/inventory_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/inventory_provider.dart';
import '../../core/providers/sales_provider.dart';
import 'inventory_form_page.dart' show InventoryFormDialog;
import 'inventory_detail_page.dart';
import '../../core/widgets/money_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() =>
      _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(inventoryProvider.notifier).load());
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<InventoryItem> _filtered(List<InventoryItem> items) {
    if (_query.isEmpty) return items;
    return items
        .where((i) =>
            i.itemName.toLowerCase().contains(_query) ||
            i.itemCode.toLowerCase().contains(_query))
        .toList();
  }

  Future<void> _openForm(InventoryItem? editing) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => InventoryFormDialog(editing: editing),
    );
  }

  Future<void> _confirmDelete(InventoryItem item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _DeleteModal(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Auto-reload when any sales invoice mutation happens (sale recorded, updated, cancelled)
    ref.listen<SalesInvoiceState>(salesInvoiceProvider, (prev, next) {
      if (prev != null && !prev.isLoading && !next.isLoading && prev.items != next.items) {
        ref.read(inventoryProvider.notifier).load();
      }
    });

    final state = ref.watch(inventoryProvider);
    final canManage = ref.watch(authProvider).hasPermission('inventory:manage');
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final filtered = _filtered(state.items);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Padding(
        padding: EdgeInsets.all(isWide ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeader(
              canManage: canManage,
              onNew: () => _openForm(null),
              onRefresh: () =>
                  ref.read(inventoryProvider.notifier).load(),
            ),
            const SizedBox(height: 16),
            // ── Search bar ────────────────────────────────────────────
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name or code…',
                hintStyle: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: AppColors.textSecondary),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 16, color: AppColors.textSecondary),
                        onPressed: () => _searchCtrl.clear(),
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
            const SizedBox(height: 12),
            if (state.error != null)
              _ErrorBanner(
                message: state.error!,
                onRetry: () =>
                    ref.read(inventoryProvider.notifier).load(),
              ),
            if (state.isLoading && state.items.isEmpty)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (state.items.isEmpty && !state.isLoading)
              _EmptyState(canManage: canManage, onNew: () => _openForm(null))
            else if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off_rounded,
                          size: 40, color: AppColors.border),
                      const SizedBox(height: 10),
                      Text('No results for "$_query"',
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => _searchCtrl.clear(),
                        child: const Text('Clear search'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: isWide
                    ? _DesktopTable(
                        canManage: canManage,
                        items: filtered,
                        onEdit: _openForm,
                        onDelete: _confirmDelete,
                      )
                    : _MobileList(
                        canManage: canManage,
                        items: filtered,
                        onEdit: _openForm,
                        onDelete: _confirmDelete,
                      ),
              ),
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
  final bool canManage;
  final VoidCallback onNew;
  final VoidCallback onRefresh;
  const _PageHeader({required this.canManage, required this.onNew, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Inventory',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  SizedBox(height: 2),
                  Text('Manage your products and stock levels',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Tooltip(
              message: 'Refresh',
              child: IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: AppColors.textSecondary,
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
            if (isWide && canManage) ...[
              const SizedBox(width: 8),
              _AddButton(onTap: onNew),
            ],
          ],
        ),
        if (!isWide && canManage) ...[
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity, child: _AddButton(onTap: onNew)),
        ],
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_rounded, size: 16),
      label: const Text('Add Item'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop table
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopTable extends StatelessWidget {
  final bool canManage;
  final List<InventoryItem> items;
  final void Function(InventoryItem) onEdit;
  final void Function(InventoryItem) onDelete;

  const _DesktopTable(
      {required this.canManage,
      required this.items,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border:
                  Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 16),
                _HeaderCell('Code', flex: 2),
                _HeaderCell('Name', flex: 3),
                _HeaderCell('Quantity', flex: 2),
                _HeaderCell('Purchase Price', flex: 2),
                _HeaderCell('Sale Price', flex: 2),
                _HeaderCell('Action', flex: 1, align: TextAlign.center),
                SizedBox(width: 16),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) => _DesktopRow(
                canManage: canManage,
                item: items[i],
                onEdit: onEdit,
                onDelete: onDelete,
              ),
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
  final TextAlign align;
  const _HeaderCell(this.label,
      {this.flex = 1, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(label,
            textAlign: align,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.3)),
      );
}

class _DesktopRow extends StatefulWidget {
  final bool canManage;
  final InventoryItem item;
  final void Function(InventoryItem) onEdit;
  final void Function(InventoryItem) onDelete;
  const _DesktopRow(
      {required this.canManage,
      required this.item,
      required this.onEdit,
      required this.onDelete});

  @override
  State<_DesktopRow> createState() => _DesktopRowState();
}

class _DesktopRowState extends State<_DesktopRow> {
  bool _hovered = false;

  String _fmtNum(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isLow = item.isLowStock;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => InventoryDetailPage(item: item),
        )),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 56,
        color: _hovered ? const Color(0xFFF0F4FF) : Colors.white,
        child: Row(
          children: [
            const SizedBox(width: 16),
            // Code
            Expanded(
              flex: 2,
              child: Text(item.itemCode,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ),
            // Name
            Expanded(
              flex: 3,
              child: Text(item.itemName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            // Quantity
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Text('${_fmtNum(item.quantity)} ${item.unitName}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isLow
                              ? AppColors.dangerText
                              : AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  if (isLow) ...[
                    const SizedBox(width: 4),
                    const Tooltip(
                      message: 'Low stock',
                      child: Icon(Icons.warning_amber_rounded,
                          size: 13, color: AppColors.dangerText),
                    ),
                  ],
                ],
              ),
            ),
            // Purchase Price
            Expanded(
              flex: 2,
              child: MoneyText(item.purchasePrice,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            // Sale Price
            Expanded(
              flex: 2,
              child: MoneyText(item.salesPrice,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            // Action
            Expanded(
              flex: 1,
              child: widget.canManage
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _IconBtn(
                            icon: Icons.edit_outlined,
                            tooltip: 'Edit',
                            onTap: () => widget.onEdit(item)),
                        const SizedBox(width: 4),
                        _IconBtn(
                            icon: Icons.delete_outline_rounded,
                            tooltip: 'Delete',
                            color: AppColors.dangerText,
                            onTap: () => widget.onDelete(item)),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 16),
          ],
        ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile list
// ─────────────────────────────────────────────────────────────────────────────

class _MobileList extends StatelessWidget {
  final bool canManage;
  final List<InventoryItem> items;
  final void Function(InventoryItem) onEdit;
  final void Function(InventoryItem) onDelete;

  const _MobileList(
      {required this.canManage,
      required this.items,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border)),
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, i) => _MobileRow(
          canManage: canManage,
          item: items[i],
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ),
    );
  }
}

class _MobileRow extends StatelessWidget {
  final bool canManage;
  final InventoryItem item;
  final void Function(InventoryItem) onEdit;
  final void Function(InventoryItem) onDelete;

  const _MobileRow(
      {required this.canManage,
      required this.item,
      required this.onEdit,
      required this.onDelete});

  String _fmtQty(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final isLow = item.isLowStock;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => InventoryDetailPage(item: item),
      )),
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Icon box
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.iconInventory.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 20, color: AppColors.iconInventory),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(item.itemCode,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          // Qty chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isLow
                  ? AppColors.dangerBg
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_fmtQty(item.quantity)} ${item.unitName}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isLow
                      ? AppColors.dangerText
                      : AppColors.textSecondary),
            ),
          ),
          if (canManage) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 18, color: AppColors.textSecondary),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(color: AppColors.dangerText)),
                ),
              ],
              onSelected: (v) {
                if (v == 'edit') onEdit(item);
                if (v == 'delete') onDelete(item);
              },
            ),
          ],
        ],
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delete modal
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteModal extends ConsumerStatefulWidget {
  final InventoryItem item;
  const _DeleteModal({required this.item});

  @override
  ConsumerState<_DeleteModal> createState() => _DeleteModalState();
}

class _DeleteModalState extends ConsumerState<_DeleteModal> {
  bool _deleting = false;

  Future<void> _confirm() async {
    setState(() => _deleting = true);
    final ok = await ref
        .read(inventoryProvider.notifier)
        .delete(widget.item.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.sidebarBackground,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              const Text('Delete Item',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5),
                  children: [
                    const TextSpan(text: 'Delete '),
                    TextSpan(
                      text: widget.item.itemName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const TextSpan(text: '? This cannot be undone.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _deleting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _deleting ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dangerText,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _deleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Text('Delete',
                            style: TextStyle(
                                fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool canManage;
  final VoidCallback onNew;
  const _EmptyState({required this.canManage, required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            const Text('No inventory items yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text(
              'Add your first product or stock item to get started.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (canManage) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorBanner({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        border:
            Border.all(color: AppColors.dangerText.withAlpha(80)),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
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

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}
