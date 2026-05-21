import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/inventory_model.dart';
import '../../core/providers/inventory_provider.dart';
import '../../core/utils/format.dart';
import 'inventory_form_page.dart' show InventoryFormDialog;

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class InventoryDetailPage extends ConsumerWidget {
  final InventoryItem item;
  const InventoryDetailPage({super.key, required this.item});

  static String _fmtQty(double v) => v == v.truncateToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryProvider);
    final live = state.items.firstWhere(
      (i) => i.id == item.id,
      orElse: () => item,
    );
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWide ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeader(
              item: live,
              isWide: isWide,
              onBack: () => Navigator.of(context).pop(),
              onEdit: () => showDialog<bool>(
                context: context,
                builder: (_) => InventoryFormDialog(editing: live),
              ),
              onDelete: () => _confirmDelete(context, ref, live),
            ),
            const SizedBox(height: 24),
            _ItemCard(item: live),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, InventoryItem it) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(item: it),
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page header
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final InventoryItem item;
  final bool isWide;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PageHeader({
    required this.item,
    required this.isWide,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _ActionBtn(
          label: 'Edit', icon: Icons.edit_outlined, onTap: onEdit),
      _ActionBtn(
        label: 'Delete',
        icon: Icons.delete_outline_rounded,
        color: AppColors.dangerText,
        onTap: onDelete,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb
        Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: const Icon(Icons.arrow_back_rounded,
                  size: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onBack,
              child: const Text('Inventory',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('/',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(
                item.itemName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Title row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.itemName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StockBadge(item: item),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.itemCode} · ${item.unitName}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (isWide) Wrap(spacing: 8, children: buttons),
          ],
        ),

        if (!isWide) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: buttons),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unified item card
// ─────────────────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final InventoryItem item;
  const _ItemCard({required this.item});

  static String _fmtQty(double v) => v == v.truncateToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final it = item;
    final isLow = it.isLowStock;
    final hasMargin = it.purchasePrice > 0 && it.salesPrice > 0;
    final margin = it.salesPrice - it.purchasePrice;
    final marginPct =
        (margin / it.purchasePrice * 100).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Details + Pricing ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field('Item Code', it.itemCode),
                      const SizedBox(height: 12),
                      _field('Unit', it.unitName),
                      const SizedBox(height: 12),
                      _field(
                        'Stock',
                        '${_fmtQty(it.quantity)} ${it.unitName}',
                        valueColor: isLow
                            ? AppColors.dangerText
                            : AppColors.successText,
                        bold: true,
                      ),
                      if (it.lowStockLevel > 0) ...[
                        const SizedBox(height: 12),
                        _field(
                          'Low Stock Alert',
                          '${_fmtQty(it.lowStockLevel)} ${it.unitName}',
                        ),
                      ],
                      if (it.description != null &&
                          it.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _field('Description', it.description!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Right: pricing
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field('Purchase Price', fmtMoney(it.purchasePrice),
                          valueFontSize: 16,
                          valueColor: AppColors.primary,
                          bold: true),
                      const SizedBox(height: 12),
                      _field('Sale Price', fmtMoney(it.salesPrice),
                          valueFontSize: 16,
                          valueColor: AppColors.cardGreen,
                          bold: true),
                      if (hasMargin) ...[
                        const SizedBox(height: 12),
                        _field(
                          'Margin',
                          '${fmtMoney(margin)} ($marginPct%)',
                          valueColor: margin >= 0
                              ? AppColors.successText
                              : AppColors.dangerText,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _field(
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
    double valueFontSize = 15,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Stock badge (inline in header)
// ─────────────────────────────────────────────────────────────────────────────

class _StockBadge extends StatelessWidget {
  final InventoryItem item;
  const _StockBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final isLow = item.isLowStock;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLow ? AppColors.dangerBg : AppColors.successBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLow) ...[
            const Icon(Icons.warning_amber_rounded,
                size: 11, color: AppColors.dangerText),
            const SizedBox(width: 4),
          ],
          Text(
            isLow ? 'Low stock' : 'In stock',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    isLow ? AppColors.dangerText : AppColors.successText),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action button
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? AppColors.primary;
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: Colors.white),
      label: Text(label,
          style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 36),
        elevation: 0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delete dialog
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteDialog extends ConsumerStatefulWidget {
  final InventoryItem item;
  const _DeleteDialog({required this.item});

  @override
  ConsumerState<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends ConsumerState<_DeleteDialog> {
  bool _deleting = false;

  Future<void> _confirm() async {
    setState(() => _deleting = true);
    final ok = await ref
        .read(inventoryProvider.notifier)
        .delete(widget.item.id);
    if (!mounted) return;
    Navigator.of(context).pop(ok);
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
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.dangerText),
                  ),
                  const SizedBox(width: 12),
                  const Text('Delete Item',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _deleting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Go back'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _deleting ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dangerText,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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
