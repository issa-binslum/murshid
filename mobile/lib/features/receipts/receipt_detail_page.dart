import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/account_model.dart';
import '../../core/models/receipt_model.dart';
import '../../core/providers/account_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/receipt_provider.dart';
import '../../core/utils/format.dart';
import '../../core/utils/pdf_downloader.dart';
import '../../core/utils/receipt_pdf.dart';
import '../../core/widgets/money_text.dart';
import 'receipt_form_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class ReceiptDetailPage extends ConsumerWidget {
  final Receipt receipt;
  const ReceiptDetailPage({super.key, required this.receipt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(receiptProvider).items.firstWhere(
          (r) => r.id == receipt.id,
          orElse: () => receipt,
        );
    final accounts = ref.watch(accountProvider).items;
    final canManage = ref.watch(authProvider).hasPermission('receipts:manage');
    final shortId = live.id.substring(0, 8).toUpperCase();
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWide ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page header ─────────────────────────────────────────────────
            _PageHeader(
              shortId: shortId,
              date: live.date,
              canManage: canManage,
              isWide: isWide,
              receiptId: live.id,
              onBack: () => Navigator.of(context).pop(),
              onPrint: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preparing print…')),
              ),
              onPdf: () => _openPdf(context, live, accounts),
              onEdit: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReceiptFormPage(editing: live),
                  fullscreenDialog: true,
                ),
              ),
              onDelete: () => _showDeleteDialog(context, ref, live),
            ),
            const SizedBox(height: 24),

            // ── Single unified card ──────────────────────────────────────────
            _ReceiptCard(
              receipt: live,
              accounts: accounts,
              shortId: shortId,
              onPrint: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preparing print…')),
              ),
              onPdf: () => _openPdf(context, live, accounts),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _openPdf(
      BuildContext context, Receipt r, List<AccountItem> accounts) async {
    final acct = accounts.where((a) => a.id == r.accountId).firstOrNull;
    final shortId = r.id.substring(0, 8).toUpperCase();
    final bytes = await buildReceiptPdf(r, acct);
    if (context.mounted) {
      await saveAndOpenPdf(context, bytes, 'Receipt_$shortId.pdf');
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Receipt r) {
    showDialog<void>(
      context: context,
      builder: (_) => _DeleteDialog(
        receipt: r,
        onDeleted: () => Navigator.of(context).pop(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unified receipt card — receipt name/ID, account, info, table all in one
// ─────────────────────────────────────────────────────────────────────────────

class _ReceiptCard extends StatelessWidget {
  final Receipt receipt;
  final List<AccountItem> accounts;
  final String shortId;
  final VoidCallback onPrint;
  final VoidCallback onPdf;

  const _ReceiptCard({
    required this.receipt,
    required this.accounts,
    required this.shortId,
    required this.onPrint,
    required this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    final acct = accounts.where((a) => a.id == receipt.accountId).firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Receipt header (name + ID + amount) ─────────────────────────
          

          // ── Receipt ID + date + info fields ─────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Receipt ID row
                

                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side: Paid By + Received In
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (receipt.paidBy != null &&
                              receipt.paidBy!.isNotEmpty) ...[
                            const Text(
                              'Paid By',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              receipt.paidBy!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          const Text(
                            'Received In',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            acct?.accountName ?? '—',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right side: Amount + Description
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
                            receipt.amount,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          if (receipt.description != null &&
                              receipt.description!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              receipt.description!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Items table (only if items exist) ───────────────────────────
          if (receipt.items.isNotEmpty) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            _ItemsSection(items: receipt.items, amount: receipt.amount),
          ],

          // ── Print / PDF actions ─────────────────────────────────────────
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          
        ],
      ),
    );
  }

  static String _accountTypeLabel(AccountType type) => switch (type) {
        AccountType.bank => 'Bank Account',
        AccountType.cash => 'Cash Account',
        AccountType.mobileWallet => 'Mobile Wallet',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Page header — breadcrumb + title + subtitle + action buttons
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final String shortId;
  final String receiptId;
  final DateTime date;
  final bool canManage;
  final bool isWide;
  final VoidCallback onBack;
  final VoidCallback onPrint;
  final VoidCallback onPdf;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PageHeader({
    required this.shortId,
    required this.receiptId,
    required this.date,
    required this.canManage,
    required this.isWide,
    required this.onBack,
    required this.onPrint,
    required this.onPdf,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _ActionBtn(label: 'Print', icon: Icons.print_outlined, onTap: onPrint),
      _ActionBtn(
          label: 'PDF', icon: Icons.picture_as_pdf_outlined, onTap: onPdf),
      if (canManage) ...[
        _ActionBtn(label: 'Edit', icon: Icons.edit_outlined, onTap: onEdit),
        _ActionBtn(
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          color: AppColors.dangerText,
          borderColor: AppColors.dangerText,
          onTap: onDelete,
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
              child: const Text('Receipts',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('/',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                    'Receipt #$shortId',
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
// Items table + totals block
// ─────────────────────────────────────────────────────────────────────────────

class _ItemsSection extends StatelessWidget {
  final List<ReceiptItem> items;
  final double amount;
  const _ItemsSection({required this.items, required this.amount});

  static const _colWidths = {
    0: FlexColumnWidth(4),
    1: FixedColumnWidth(64),
    2: FixedColumnWidth(90),
    3: FixedColumnWidth(90),
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Table(
          columnWidths: _colWidths,
          children: [
            TableRow(
              decoration: const BoxDecoration(color: AppColors.primary),
              children: [
                _th('Item', TextAlign.left),
                _th('Qty', TextAlign.right),
                _th('Unit Price', TextAlign.right),
                _th('Total', TextAlign.right),
              ],
            ),
          ],
        ),
        // Data rows
        Table(
          columnWidths: _colWidths,
          children: items.asMap().entries.map((e) {
            final item = e.value;
            final even = e.key.isEven;
            return TableRow(
              decoration: BoxDecoration(
                color: even ? Colors.white : const Color(0xFFF5F5F4),
                border:
                    const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              children: [
                _td(item.itemName, TextAlign.left),
                _td(fmtNumber(item.qty), TextAlign.right),
                _tdMoney(item.unitPrice, TextAlign.right,
                    color: AppColors.textSecondary),
                _tdMoney(item.total, TextAlign.right, bold: true),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Totals — right-aligned block
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 260,
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
              },
              children: [
                _totalRowMoney('Amount', amount),
                _totalRow('Lines', '${items.length}'),
                _totalRowMoney('Grand Total', amount,
                    dark: true, valueColor: AppColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  static Widget _th(String text, TextAlign align) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(text,
            textAlign: align,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      );

  static Widget _td(String text, TextAlign align,
          {Color? color, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Text(text,
            textAlign: align,
            style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
                color: color ?? AppColors.textPrimary)),
      );

  static Widget _tdMoney(double amount, TextAlign align,
          {Color? color, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: MoneyText(amount,
            textAlign: align,
            style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
                color: color ?? AppColors.textPrimary)),
      );

  static TableRow _totalRow(String label, String value,
      {bool dark = false, Color? valueColor}) {
    final labelBg = AppColors.primary;
    final valueBg = dark ? Colors.white : const Color(0xFFF5F5F4);
    return TableRow(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0x33FFFFFF)))),
      children: [
        Container(
          color: labelBg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
        Container(
          color: valueBg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: dark ? FontWeight.w700 : FontWeight.w500,
                  color: valueColor ?? AppColors.textPrimary)),
        ),
      ],
    );
  }

  static TableRow _totalRowMoney(String label, double amount,
      {bool dark = false, Color? valueColor}) {
    final labelBg = AppColors.primary;
    final valueBg = dark ? Colors.white : const Color(0xFFF5F5F4);
    return TableRow(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0x33FFFFFF)))),
      children: [
        Container(
          color: labelBg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
        Container(
          color: valueBg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: MoneyText(amount,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: dark ? FontWeight.w700 : FontWeight.w500,
                  color: valueColor ?? AppColors.textPrimary)),
        ),
      ],
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
  final Color? borderColor;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.borderColor,
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
  final Receipt receipt;
  final VoidCallback onDeleted;
  const _DeleteDialog({required this.receipt, required this.onDeleted});

  @override
  ConsumerState<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends ConsumerState<_DeleteDialog> {
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final ok =
        await ref.read(receiptProvider.notifier).delete(widget.receipt.id);
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
    final label = widget.receipt.paidBy ?? 'this receipt';
    return Dialog(
      backgroundColor: AppColors.sidebarBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
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
                  const Text('Delete receipt?',
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
                    const TextSpan(text: 'Delete receipt from '),
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
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
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