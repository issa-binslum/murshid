import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/account_model.dart';
import '../../core/models/payment_model.dart';
import '../../core/providers/account_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/payment_provider.dart';
import '../../core/utils/pdf_downloader.dart';
import '../../core/utils/payment_pdf.dart';
import '../../core/widgets/money_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class PaymentDetailPage extends ConsumerWidget {
  final Payment payment;
  const PaymentDetailPage({super.key, required this.payment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(paymentProvider).items.firstWhere(
          (p) => p.id == payment.id,
          orElse: () => payment,
        );
    final accounts = ref.watch(accountProvider).items;
    final canManage =
        ref.watch(authProvider).hasPermission('payments:manage');
    final shortId = live.id.substring(0, 8).toUpperCase();
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWide ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeader(
              shortId: shortId,
              paymentId: live.id,
              date: live.date,
              canManage: canManage,
              isWide: isWide,
              onBack: () => Navigator.of(context).pop(),
              onPrint: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preparing print…')),
              ),
              onPdf: () => _openPdf(context, live, accounts),
              onDelete: () => _showDeleteDialog(context, ref, live),
            ),
            const SizedBox(height: 24),
            _PaymentCard(payment: live, accounts: accounts),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _openPdf(
      BuildContext context, Payment p, List<AccountItem> accounts) async {
    final acct = accounts.where((a) => a.id == p.accountId).firstOrNull;
    final shortId = p.id.substring(0, 8).toUpperCase();
    final bytes = await buildPaymentPdf(p, acct);
    if (context.mounted) {
      await saveAndOpenPdf(context, bytes, 'Payment_$shortId.pdf');
    }
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, Payment p) {
    showDialog<void>(
      context: context,
      builder: (_) => _DeleteDialog(
        payment: p,
        onDeleted: () => Navigator.of(context).pop(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page header — breadcrumb + title + action buttons
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final String shortId;
  final String paymentId;
  final DateTime date;
  final bool canManage;
  final bool isWide;
  final VoidCallback onBack;
  final VoidCallback onPrint;
  final VoidCallback onPdf;
  final VoidCallback onDelete;

  const _PageHeader({
    required this.shortId,
    required this.paymentId,
    required this.date,
    required this.canManage,
    required this.isWide,
    required this.onBack,
    required this.onPrint,
    required this.onPdf,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _ActionBtn(
          label: 'Print', icon: Icons.print_outlined, onTap: onPrint),
      _ActionBtn(
          label: 'PDF',
          icon: Icons.picture_as_pdf_outlined,
          onTap: onPdf),
      _CopyIdBtn(paymentId: paymentId),
      if (canManage)
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
              child: const Text('Payments',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('/',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
            Text('#$shortId',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
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
                    'Payment #$shortId',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _fmtDate(date),
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
// Unified payment card
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final Payment payment;
  final List<AccountItem> accounts;

  const _PaymentCard({required this.payment, required this.accounts});

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final acct = accounts.where((a) => a.id == p.accountId).firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Payee + Paid From
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.payee != null && p.payee!.isNotEmpty) ...[
                    _field('Payee', p.payee!),
                    const SizedBox(height: 12),
                  ],
                  _field('Paid From', acct?.accountName ?? '—'),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right: Amount + Description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  MoneyText(
                    p.amount,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.iconPayments,
                    ),
                  ),
                  if (p.description != null &&
                      p.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _field('Description', p.description!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _field(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
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
// Copy ID button
// ─────────────────────────────────────────────────────────────────────────────

class _CopyIdBtn extends StatefulWidget {
  final String paymentId;
  const _CopyIdBtn({required this.paymentId});

  @override
  State<_CopyIdBtn> createState() => _CopyIdBtnState();
}

class _CopyIdBtnState extends State<_CopyIdBtn> {
  bool _copied = false;

  Future<void> _copy() async {
    final shortId = widget.paymentId.substring(0, 8).toUpperCase();
    await Clipboard.setData(ClipboardData(text: '#$shortId'));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        _copied ? AppColors.iconPayments : AppColors.textSecondary;
    return ElevatedButton.icon(
      onPressed: _copy,
      icon: Icon(
        _copied ? Icons.check_rounded : Icons.copy_outlined,
        size: 15,
        color: Colors.white,
      ),
      label: Text(
        _copied ? 'Copied!' : 'Copy ID',
        style: const TextStyle(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
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
  final Payment payment;
  final VoidCallback onDeleted;
  const _DeleteDialog({required this.payment, required this.onDeleted});

  @override
  ConsumerState<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends ConsumerState<_DeleteDialog> {
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final ok =
        await ref.read(paymentProvider.notifier).delete(widget.payment.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      widget.onDeleted();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.payment.payee ?? 'this payment';
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
                  const Text('Delete Payment',
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
                    const TextSpan(text: 'Delete payment to '),
                    TextSpan(
                      text: label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const TextSpan(
                        text:
                            '? This will reverse the account balance and cannot be undone.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _busy ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dangerText,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _busy
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
// Helper
// ─────────────────────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} / '
    '${d.month.toString().padLeft(2, '0')} / '
    '${d.year}';
