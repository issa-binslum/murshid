import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/sales_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/sales_provider.dart';
import '../../core/utils/format.dart';
import '../../core/utils/pdf_downloader.dart';
import '../../core/utils/sales_order_pdf.dart';
import '../../core/widgets/money_text.dart';
import 'sales_invoice_form_page.dart';
import 'sales_order_form_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class SalesOrderDetailPage extends ConsumerWidget {
  final SalesOrder order;
  const SalesOrderDetailPage({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(salesOrderProvider).items.firstWhere(
          (o) => o.id == order.id,
          orElse: () => order,
        );
    final canManage = ref.watch(authProvider).hasPermission('sales:manage');
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
              isCancelled: live.isCancelled,
              onBack: () => Navigator.of(context).pop(),
              onCopyToInvoice: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SalesInvoiceFormPage(fromOrder: live),
                  fullscreenDialog: true,
                ),
              ),
              onDuplicateOrder: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SalesOrderFormPage(fromOrder: live),
                  fullscreenDialog: true,
                ),
              ),
              onPrint: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preparing print…')),
              ),
              onPdf: () async {
                final bytes = await buildSalesOrderPdf(live);
                if (context.mounted) {
                  await saveAndOpenPdf(
                      context, bytes, 'SalesOrder_$shortId.pdf');
                }
              },
              onEdit: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SalesOrderFormPage(editing: live),
                  fullscreenDialog: true,
                ),
              ),
              onCancel: live.isCancelled
                  ? null
                  : () => _showCancelDialog(context, ref, live),
            ),
            const SizedBox(height: 24),

            // ── Cancelled banner ────────────────────────────────────────────
            if (live.isCancelled) ...[
              _CancelledBanner(),
              const SizedBox(height: 16),
            ],

            // ── Single unified card ──────────────────────────────────────────
            _OrderCard(
              order: live,
              shortId: shortId,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(
      BuildContext context, WidgetRef ref, SalesOrder o) {
    showDialog<void>(
      context: context,
      builder: (_) => _CancelOrderDialog(
        order: o,
        onCancelled: () => Navigator.of(context).pop(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unified order card — order info + items table all in one
// ─────────────────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final SalesOrder order;
  final String shortId;

  const _OrderCard({
    required this.order,
    required this.shortId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Customer and Order Info ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Customer + Order Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.customerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (order.address != null &&
                          order.address!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Address',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.address!,
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
                const SizedBox(width: 24),
                // Right: Total Amount + Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      MoneyText(
                        order.total,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      if (order.description != null &&
                          order.description!.isNotEmpty) ...[
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
                          order.description!,
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
          ),

          // ── Items table ────────────────────────────────────────────────
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          _ItemsSection(items: order.items, total: order.total),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page header — breadcrumb + title + subtitle + action buttons
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final String shortId;
  final DateTime date;
  final bool canManage;
  final bool isWide;
  final bool isCancelled;
  final VoidCallback onBack;
  final VoidCallback onPrint;
  final VoidCallback onPdf;
  final VoidCallback onEdit;
  final VoidCallback onCopyToInvoice;
  final VoidCallback onDuplicateOrder;
  final VoidCallback? onCancel;

  const _PageHeader({
    required this.shortId,
    required this.date,
    required this.canManage,
    required this.isWide,
    required this.isCancelled,
    required this.onBack,
    required this.onPrint,
    required this.onPdf,
    required this.onEdit,
    required this.onCopyToInvoice,
    required this.onDuplicateOrder,
    this.onCancel,
  });

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _ActionBtn(label: 'Print', icon: Icons.print_outlined, onTap: onPrint),
      _ActionBtn(label: 'PDF', icon: Icons.picture_as_pdf_outlined, onTap: onPdf),
      _CopyToBtn(onCopyToInvoice: onCopyToInvoice, onDuplicateOrder: onDuplicateOrder),
      if (canManage && !isCancelled) ...[
        _ActionBtn(label: 'Edit', icon: Icons.edit_outlined, onTap: onEdit),
        if (onCancel != null)
          _ActionBtn(
            label: 'Cancel',
            icon: Icons.cancel_outlined,
            color: AppColors.dangerText,
            onTap: onCancel!,
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
              child: const Text('Sales Orders',
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
                    'Order #$shortId',
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
// Cancelled banner
// ─────────────────────────────────────────────────────────────────────────────

class _CancelledBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.dangerText.withAlpha(60)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cancel_outlined,
              size: 16, color: AppColors.dangerText),
          SizedBox(width: 8),
          Text(
            'This order has been cancelled.',
            style: TextStyle(
                fontSize: 13,
                color: AppColors.dangerText,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Items table + totals block
// ─────────────────────────────────────────────────────────────────────────────

class _ItemsSection extends StatelessWidget {
  final List<SalesOrderItem> items;
  final double total;
  const _ItemsSection({required this.items, required this.total});

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
                _totalRowMoney('Subtotal', total),
                _totalRow('Lines', '${items.length}'),
                _totalRowMoney('Grand Total', total,
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
// Copy To split dropdown button
// ─────────────────────────────────────────────────────────────────────────────

class _CopyToBtn extends StatelessWidget {
  final VoidCallback onCopyToInvoice;
  final VoidCallback onDuplicateOrder;
  const _CopyToBtn({required this.onCopyToInvoice, required this.onDuplicateOrder});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) {
        if (value == 'invoice') onCopyToInvoice();
        if (value == 'duplicate') onDuplicateOrder();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'invoice',
          child: Row(
            children: [
              Icon(Icons.description_outlined, size: 16,
                  color: AppColors.textPrimary),
              SizedBox(width: 10),
              Text('Sales Invoice',
                  style: TextStyle(fontSize: 13,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.content_copy_outlined, size: 16,
                  color: AppColors.textPrimary),
              SizedBox(width: 10),
              Text('Duplicate Order',
                  style: TextStyle(fontSize: 13,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.textSecondary,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Copy To',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
            SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cancel order dialog
// ─────────────────────────────────────────────────────────────────────────────

class _CancelOrderDialog extends ConsumerStatefulWidget {
  final SalesOrder order;
  final VoidCallback onCancelled;
  const _CancelOrderDialog(
      {required this.order, required this.onCancelled});

  @override
  ConsumerState<_CancelOrderDialog> createState() =>
      _CancelOrderDialogState();
}

class _CancelOrderDialogState
    extends ConsumerState<_CancelOrderDialog> {
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final ok = await ref
        .read(salesOrderProvider.notifier)
        .cancel(widget.order.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      widget.onCancelled();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortId =
        widget.order.id.substring(0, 8).toUpperCase();
    return Dialog(
      backgroundColor: AppColors.sidebarBackground,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 32, vertical: 80),
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
                    child: const Icon(Icons.cancel_outlined,
                        size: 18, color: AppColors.dangerText),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Cancel order?',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
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
                    const TextSpan(
                        text: 'You are about to cancel order '),
                    TextSpan(
                      text: '#$shortId',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const TextSpan(
                        text: '. This cannot be undone.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Go back'),
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
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Text('Yes, cancel',
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