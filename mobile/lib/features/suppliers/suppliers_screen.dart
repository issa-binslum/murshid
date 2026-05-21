import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/supplier_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/supplier_provider.dart';
import '../../core/widgets/money_text.dart';
import 'supplier_detail_page.dart';
import 'supplier_form_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(supplierProvider.notifier).load());
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Supplier> _filtered(List<Supplier> items) {
    if (_query.isEmpty) return items;
    return items
        .where((s) =>
            s.name.toLowerCase().contains(_query) ||
            (s.phone?.toLowerCase().contains(_query) ?? false) ||
            (s.email?.toLowerCase().contains(_query) ?? false))
        .toList();
  }

  Future<void> _openForm(Supplier? editing) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => SupplierFormDialog(editing: editing),
    );
  }

  Future<void> _confirmDelete(Supplier supplier) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _DeleteModal(supplier: supplier),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplierProvider);
    final canManage =
        ref.watch(authProvider).hasPermission('suppliers:manage');
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
              onRefresh: () => ref.read(supplierProvider.notifier).load(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, phone or email…',
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
                    ref.read(supplierProvider.notifier).load(),
              ),
            if (state.isLoading && state.items.isEmpty)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (state.items.isEmpty && !state.isLoading)
              _EmptyState(
                  canManage: canManage, onNew: () => _openForm(null))
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
  const _PageHeader(
      {required this.canManage,
      required this.onNew,
      required this.onRefresh});

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
                  Text('Suppliers',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  SizedBox(height: 2),
                  Text('Manage your supplier accounts',
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
      label: const Text('Add Supplier'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6)),
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
  final List<Supplier> items;
  final void Function(Supplier) onEdit;
  final void Function(Supplier) onDelete;

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
                _HeaderCell('Name', flex: 3),
                _HeaderCell('Phone', flex: 2),
                _HeaderCell('Email', flex: 3),
                _HeaderCell('Credit Limit', flex: 2),
                _HeaderCell('Balance', flex: 2),
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
                supplier: items[i],
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
  final Supplier supplier;
  final void Function(Supplier) onEdit;
  final void Function(Supplier) onDelete;
  const _DesktopRow(
      {required this.canManage,
      required this.supplier,
      required this.onEdit,
      required this.onDelete});

  @override
  State<_DesktopRow> createState() => _DesktopRowState();
}

class _DesktopRowState extends State<_DesktopRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.supplier;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SupplierDetailPage(supplier: s),
        )),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 52,
          color: _hovered ? const Color(0xFFF0F4FF) : Colors.white,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Text(s.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 2,
                child: Text(s.phone ?? '—',
                    style: TextStyle(
                        fontSize: 13,
                        color: s.phone != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 3,
                child: Text(s.email ?? '—',
                    style: TextStyle(
                        fontSize: 13,
                        color: s.email != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 2,
                child: MoneyText(s.creditLimit,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 2,
                child: MoneyText(s.balance,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: s.balance < 0
                            ? AppColors.dangerText
                            : AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 1,
                child: widget.canManage
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _IconBtn(
                              icon: Icons.edit_outlined,
                              tooltip: 'Edit',
                              onTap: () => widget.onEdit(s)),
                          const SizedBox(width: 4),
                          _IconBtn(
                              icon: Icons.delete_outline_rounded,
                              tooltip: 'Delete',
                              color: AppColors.dangerText,
                              onTap: () => widget.onDelete(s)),
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
  final List<Supplier> items;
  final void Function(Supplier) onEdit;
  final void Function(Supplier) onDelete;

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
          supplier: items[i],
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ),
    );
  }
}

class _MobileRow extends StatelessWidget {
  final bool canManage;
  final Supplier supplier;
  final void Function(Supplier) onEdit;
  final void Function(Supplier) onDelete;

  const _MobileRow(
      {required this.canManage,
      required this.supplier,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SupplierDetailPage(supplier: s),
      )),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.iconSuppliers.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.store_outlined,
                  size: 20, color: AppColors.iconSuppliers),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(s.phone ?? s.email ?? '—',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: MoneyText(
                s.balance,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: s.balance < 0
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
                  const PopupMenuItem(
                      value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style:
                            TextStyle(color: AppColors.dangerText)),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'edit') onEdit(s);
                  if (v == 'delete') onDelete(s);
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
  final Supplier supplier;
  const _DeleteModal({required this.supplier});

  @override
  ConsumerState<_DeleteModal> createState() => _DeleteModalState();
}

class _DeleteModalState extends ConsumerState<_DeleteModal> {
  bool _deleting = false;

  Future<void> _confirm() async {
    setState(() => _deleting = true);
    final ok = await ref
        .read(supplierProvider.notifier)
        .delete(widget.supplier.id);
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
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
              const Text('Delete Supplier',
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
                      text: widget.supplier.name,
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
                                strokeWidth: 2, color: Colors.white))
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
            const Icon(Icons.store_outlined,
                size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            const Text('No suppliers yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text(
              'Add your first supplier to get started.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (canManage) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Supplier'),
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
