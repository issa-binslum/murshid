import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/customer_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/customer_provider.dart';
import '../../core/utils/format.dart';
import 'customer_form_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class CustomerDetailPage extends ConsumerWidget {
  final Customer customer;
  const CustomerDetailPage({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerProvider);
    final live = state.items.firstWhere((c) => c.id == customer.id,
        orElse: () => customer);
    final canManage =
        ref.watch(authProvider).hasPermission('customers:manage');
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWide ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeader(
              customer: live,
              canManage: canManage,
              isWide: isWide,
              onBack: () => Navigator.of(context).pop(),
              onEdit: () async {
                await showDialog<bool>(
                  context: context,
                  builder: (_) => CustomerFormDialog(editing: live),
                );
              },
              onDelete: canManage
                  ? () => _showDeleteDialog(context, ref, live)
                  : null,
            ),
            const SizedBox(height: 24),
            _CustomerCard(customer: live),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, Customer c) {
    showDialog<void>(
      context: context,
      builder: (_) => _DeleteDialog(
        customer: c,
        onDeleted: () => Navigator.of(context).pop(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page header — breadcrumb + title + action buttons
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final Customer customer;
  final bool canManage;
  final bool isWide;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _PageHeader({
    required this.customer,
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
              child: const Text('Customers',
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
                customer.name,
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
                    customer.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (customer.phone != null || customer.email != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      customer.phone ?? customer.email!,
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
// Unified customer card
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  const _CustomerCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final hasAddresses =
        (c.billingAddress != null && c.billingAddress!.isNotEmpty) ||
            (c.deliveryAddress != null && c.deliveryAddress!.isNotEmpty);

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
                      _field('Name', c.name),
                      if (c.phone != null && c.phone!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _field('Phone', c.phone!),
                      ],
                      if (c.email != null && c.email!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _field('Email', c.email!),
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
                        fmtMoney(c.balance),
                        valueColor: c.balance < 0
                            ? AppColors.dangerText
                            : AppColors.primary,
                        bold: true,
                        valueFontSize: 16,
                      ),
                      const SizedBox(height: 12),
                      _field('Credit Limit', fmtMoney(c.creditLimit)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Addresses ────────────────────────────────────────────────
          if (hasAddresses) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: c.billingAddress != null &&
                            c.billingAddress!.isNotEmpty
                        ? _field('Billing Address', c.billingAddress!)
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: c.deliveryAddress != null &&
                            c.deliveryAddress!.isNotEmpty
                        ? _field('Delivery Address', c.deliveryAddress!)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
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
  final Customer customer;
  final VoidCallback onDeleted;
  const _DeleteDialog(
      {required this.customer, required this.onDeleted});

  @override
  ConsumerState<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends ConsumerState<_DeleteDialog> {
  bool _deleting = false;

  Future<void> _confirm() async {
    setState(() => _deleting = true);
    final ok = await ref
        .read(customerProvider.notifier)
        .delete(widget.customer.id);
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
                  const Text('Delete Customer',
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
                      text: widget.customer.name,
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
                            style: TextStyle(fontWeight: FontWeight.w600)),
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
