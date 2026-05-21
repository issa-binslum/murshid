import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/supplier_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/supplier_provider.dart';
import '../../core/utils/format.dart';
import 'supplier_form_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class SupplierDetailPage extends ConsumerWidget {
  final Supplier supplier;
  const SupplierDetailPage({super.key, required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supplierProvider);
    final live = state.items.firstWhere((s) => s.id == supplier.id,
        orElse: () => supplier);
    final canManage =
        ref.watch(authProvider).hasPermission('suppliers:manage');
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWide ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeader(
              supplier: live,
              canManage: canManage,
              isWide: isWide,
              onBack: () => Navigator.of(context).pop(),
              onEdit: () async {
                await showDialog<bool>(
                  context: context,
                  builder: (_) => SupplierFormDialog(editing: live),
                );
              },
              onDelete: canManage
                  ? () => _showDeleteDialog(context, ref, live)
                  : null,
            ),
            const SizedBox(height: 24),
            _SupplierCard(supplier: live),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, Supplier s) {
    showDialog<void>(
      context: context,
      builder: (_) => _DeleteDialog(
        supplier: s,
        onDeleted: () => Navigator.of(context).pop(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page header — breadcrumb + title + action buttons
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final Supplier supplier;
  final bool canManage;
  final bool isWide;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _PageHeader({
    required this.supplier,
    required this.canManage,
    required this.isWide,
    required this.onBack,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = [
      if (canManage) ...[
        _ActionBtn(
            label: 'Edit', icon: Icons.edit_outlined, onTap: onEdit),
        if (onDelete != null)
          _ActionBtn(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            color: AppColors.dangerText,
            onTap: onDelete!,
          ),
      ],
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
              child: const Text('Suppliers',
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
                supplier.name,
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
                  Text(
                    supplier.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (supplier.phone != null || supplier.email != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      supplier.phone ?? supplier.email!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (isWide && buttons.isNotEmpty)
              Wrap(spacing: 8, children: buttons),
          ],
        ),

        if (!isWide && buttons.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: buttons),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unified supplier card
// ─────────────────────────────────────────────────────────────────────────────

class _SupplierCard extends StatelessWidget {
  final Supplier supplier;
  const _SupplierCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    final hasAddress = s.address != null && s.address!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Contact + Financial ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: contact info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field('Name', s.name),
                      if (s.phone != null && s.phone!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _field('Phone', s.phone!),
                      ],
                      if (s.email != null && s.email!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _field('Email', s.email!),
                      ],
                      if (hasAddress) ...[
                        const SizedBox(height: 12),
                        _field('Address', s.address!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Right: financial info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field(
                        'Balance',
                        fmtMoney(s.balance),
                        valueColor: s.balance < 0
                            ? AppColors.dangerText
                            : AppColors.primary,
                        bold: true,
                        valueFontSize: 16,
                      ),
                      const SizedBox(height: 12),
                      _field('Credit Limit', fmtMoney(s.creditLimit)),
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
  final Supplier supplier;
  final VoidCallback onDeleted;
  const _DeleteDialog(
      {required this.supplier, required this.onDeleted});

  @override
  ConsumerState<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends ConsumerState<_DeleteDialog> {
  bool _deleting = false;

  Future<void> _confirm() async {
    setState(() => _deleting = true);
    final ok = await ref
        .read(supplierProvider.notifier)
        .delete(widget.supplier.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      widget.onDeleted();
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
                  const Text('Delete Supplier',
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
                      text: widget.supplier.name,
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
                        : () => Navigator.of(context).pop(),
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
