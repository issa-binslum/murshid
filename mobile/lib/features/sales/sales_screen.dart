import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/sales_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/receipt_provider.dart';
import '../../core/providers/sales_provider.dart';
import '../../core/widgets/money_text.dart';
import 'sales_order_detail_page.dart';
import 'sales_order_form_page.dart';
import 'sales_invoice_detail_page.dart';
import 'sales_invoice_form_page.dart';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(authProvider).hasPermission('sales:manage');
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 700;
    final isCompact = size.height < 500;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        resizeToAvoidBottomInset: !isCompact,
        backgroundColor: AppColors.pageBackground,
        body: Padding(
          padding: EdgeInsets.all(isWide ? 32 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Page header ──
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sales',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage your sales orders and invoices',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (ctx) {
                      final tab = DefaultTabController.of(ctx);
                      return Tooltip(
                        message: 'Refresh',
                        child: IconButton(
                          onPressed: () {
                            if (tab.index == 0) {
                              ref.read(salesOrderProvider.notifier).load();
                            } else {
                              ref.read(salesInvoiceProvider.notifier).load();
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          color: AppColors.textSecondary,
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // ── Tab bar ──
              Container(
                decoration: BoxDecoration(
                  color: AppColors.sidebarBackground,
                  border: Border.all(color: AppColors.border),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w400),
                  tabs: const [
                    Tab(text: 'Orders'),
                    Tab(text: 'Invoices'),
                  ],
                ),
              ),
              // ── Tab content ──
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      left: BorderSide(color: AppColors.border),
                      right: BorderSide(color: AppColors.border),
                      bottom: BorderSide(color: AppColors.border),
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    child: TabBarView(
                      children: [
                        _OrdersTab(canManage: canManage),
                        _InvoicesTab(canManage: canManage),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Orders tab
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersTab extends ConsumerStatefulWidget {
  final bool canManage;
  const _OrdersTab({required this.canManage});

  @override
  ConsumerState<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<_OrdersTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salesOrderProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(salesOrderProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 700;

    final filtered = _q.isEmpty
        ? state.items
        : state.items.where((o) {
            final q = _q.toLowerCase();
            return o.customerName.toLowerCase().contains(q) ||
                (o.address?.toLowerCase().contains(q) ?? false) ||
                (o.description?.toLowerCase().contains(q) ?? false);
          }).toList();

    return Column(
      children: [
        _TabHeader(
          ctrl: _searchCtrl,
          hint: 'Search orders…',
          onSearch: (v) => setState(() => _q = v),
          canManage: widget.canManage,
          onAdd: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const SalesOrderFormPage(),
            fullscreenDialog: true,
          )),
          addLabel: 'New Order',
        ),
        if (state.isLoading)
          const LinearProgressIndicator(
              color: AppColors.primary, backgroundColor: AppColors.border),
        if (state.error != null) _ErrorBanner(message: state.error!),
        if (!state.isLoading && filtered.isEmpty)
          _EmptyState(
            icon: Icons.receipt_long_outlined,
            label: 'No sales orders yet',
            canManage: widget.canManage,
            onAdd: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SalesOrderFormPage(),
              fullscreenDialog: true,
            )),
          ),
        if (filtered.isNotEmpty)
          Expanded(
            child: isWide
                ? _OrdersDesktopTable(orders: filtered, canManage: widget.canManage)
                : _OrdersMobileList(orders: filtered, canManage: widget.canManage),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invoices tab
// ─────────────────────────────────────────────────────────────────────────────

class _InvoicesTab extends ConsumerStatefulWidget {
  final bool canManage;
  const _InvoicesTab({required this.canManage});

  @override
  ConsumerState<_InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends ConsumerState<_InvoicesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salesInvoiceProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Auto-reload when any receipt mutation happens (create, update, or delete)
    ref.listen<ReceiptState>(receiptProvider, (prev, next) {
      if (prev != null && !prev.isLoading && !next.isLoading && prev.items != next.items) {
        ref.read(salesInvoiceProvider.notifier).load();
      }
    });

    final state = ref.watch(salesInvoiceProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 700;

    final filtered = _q.isEmpty
        ? state.items
        : state.items.where((inv) {
            final q = _q.toLowerCase();
            return inv.customerName.toLowerCase().contains(q) ||
                (inv.description?.toLowerCase().contains(q) ?? false);
          }).toList();

    return Column(
      children: [
        _TabHeader(
          ctrl: _searchCtrl,
          hint: 'Search invoices…',
          onSearch: (v) => setState(() => _q = v),
          canManage: widget.canManage,
          onAdd: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const SalesInvoiceFormPage(),
            fullscreenDialog: true,
          )),
          addLabel: 'New Invoice',
        ),
        if (state.isLoading)
          const LinearProgressIndicator(
              color: AppColors.primary, backgroundColor: AppColors.border),
        if (state.error != null) _ErrorBanner(message: state.error!),
        if (!state.isLoading && filtered.isEmpty)
          _EmptyState(
            icon: Icons.description_outlined,
            label: 'No sales invoices yet',
            canManage: widget.canManage,
            onAdd: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SalesInvoiceFormPage(),
              fullscreenDialog: true,
            )),
          ),
        if (filtered.isNotEmpty)
          Expanded(
            child: isWide
                ? _InvoicesDesktopTable(invoices: filtered, canManage: widget.canManage)
                : _InvoicesMobileList(invoices: filtered, canManage: widget.canManage),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared search + action header
// ─────────────────────────────────────────────────────────────────────────────

class _TabHeader extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final ValueChanged<String> onSearch;
  final bool canManage;
  final VoidCallback onAdd;
  final String addLabel;

  const _TabHeader({
    required this.ctrl,
    required this.hint,
    required this.onSearch,
    required this.canManage,
    required this.onAdd,
    required this.addLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.sidebarBackground,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 24 : 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: ctrl,
                onChanged: onSearch,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: AppColors.textSecondary),
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: AppColors.pageBackground,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
                ),
              ),
            ),
          ),
          if (canManage) ...[
            const SizedBox(width: 12),
            if (isWide)
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded,
                    size: 16, color: Colors.white),
                label: Text(addLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              )
            else
              SizedBox(
                height: 38,
                width: 38,
                child: ElevatedButton(
                  onPressed: onAdd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Icon(Icons.add_rounded,
                      size: 20, color: Colors.white),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Orders — desktop table
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersDesktopTable extends StatelessWidget {
  final List<SalesOrder> orders;
  final bool canManage;
  const _OrdersDesktopTable({required this.orders, required this.canManage});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFECEEF2),
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
          child: const Row(
            children: [
              Expanded(flex: 30, child: _ColHead(label: 'Customer')),
              Expanded(flex: 20, child: _ColHead(label: 'Date')),
              Expanded(flex: 28, child: _ColHead(label: 'Description')),
              Expanded(
                  flex: 18, child: _ColHead(label: 'Total', right: true)),
              SizedBox(width: 16),
              Expanded(flex: 16, child: _ColHead(label: 'Status')),
              SizedBox(width: 40),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: orders.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (_, i) =>
                _OrdersDesktopRow(order: orders[i], canManage: canManage, index: i),
          ),
        ),
      ],
    );
  }
}

class _OrdersDesktopRow extends ConsumerWidget {
  final SalesOrder order;
  final bool canManage;
  final int index;
  const _OrdersDesktopRow(
      {required this.order, required this.canManage, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = index.isOdd ? const Color(0xFFF9FAFB) : Colors.white;
    return Material(
      color: bg,
      child: InkWell(
        hoverColor: const Color(0xFFEFF6FF),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SalesOrderDetailPage(order: order),
        )),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 30,
                child: Text(order.customerName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 20,
                child: Text(_fmtDate(order.date),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
              Expanded(
                flex: 28,
                child: Text(order.description ?? order.address ?? '—',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 18,
                child: MoneyText(order.total,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 16,
                child: order.isCancelled
                    ? _StatusChip(
                        label: 'Cancelled',
                        bg: AppColors.dangerBg,
                        color: AppColors.dangerText)
                    : _StatusChip(
                        label: 'Active',
                        bg: AppColors.successBg,
                        color: AppColors.successText),
              ),
              SizedBox(
                width: 40,
                child: canManage && !order.isCancelled
                    ? _OrderActions(order: order)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _OrderActions extends ConsumerWidget {
  final SalesOrder order;
  const _OrderActions({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit') {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SalesOrderFormPage(editing: order),
            fullscreenDialog: true,
          ));
        } else if (v == 'cancel') {
          ref.read(salesOrderProvider.notifier).cancel(order.id);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'edit',
            child: Text('Edit', style: TextStyle(fontSize: 13))),
        const PopupMenuItem(
            value: 'cancel',
            child: Text('Cancel',
                style:
                    TextStyle(fontSize: 13, color: AppColors.dangerText))),
      ],
      child: const Icon(Icons.more_vert_rounded,
          size: 18, color: AppColors.textSecondary),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Orders — mobile list
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersMobileList extends StatelessWidget {
  final List<SalesOrder> orders;
  final bool canManage;
  const _OrdersMobileList({required this.orders, required this.canManage});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      // ── Outer list padding so rows don't kiss the screen edges ──
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: orders.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) =>
          _OrdersMobileRow(order: orders[i], canManage: canManage),
    );
  }
}

class _OrdersMobileRow extends ConsumerWidget {
  final SalesOrder order;
  final bool canManage;
  const _OrdersMobileRow({required this.order, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SalesOrderDetailPage(order: order),
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.iconSales.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  size: 18, color: AppColors.iconSales),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.customerName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(_fmtDate(order.date),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(order.total,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                order.isCancelled
                    ? _StatusChip(
                        label: 'Cancelled',
                        bg: AppColors.dangerBg,
                        color: AppColors.dangerText)
                    : _StatusChip(
                        label: 'Active',
                        bg: AppColors.successBg,
                        color: AppColors.successText),
              ],
            ),
            if (canManage && !order.isCancelled) ...[
              const SizedBox(width: 4),
              _OrderActions(order: order),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Invoices — desktop table
// ─────────────────────────────────────────────────────────────────────────────

class _InvoicesDesktopTable extends StatelessWidget {
  final List<SalesInvoice> invoices;
  final bool canManage;
  const _InvoicesDesktopTable(
      {required this.invoices, required this.canManage});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFECEEF2),
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
          child: const Row(
            children: [
              Expanded(flex: 28, child: _ColHead(label: 'Customer')),
              Expanded(flex: 18, child: _ColHead(label: 'Date')),
              Expanded(
                  flex: 16, child: _ColHead(label: 'Total', right: true)),
              SizedBox(width: 16),
              Expanded(
                  flex: 16, child: _ColHead(label: 'Balance', right: true)),
              SizedBox(width: 16),
              Expanded(flex: 14, child: _ColHead(label: 'Status')),
              SizedBox(width: 40),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: invoices.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (_, i) => _InvoicesDesktopRow(
                invoice: invoices[i], canManage: canManage, index: i),
          ),
        ),
      ],
    );
  }
}

class _InvoicesDesktopRow extends ConsumerWidget {
  final SalesInvoice invoice;
  final bool canManage;
  final int index;
  const _InvoicesDesktopRow(
      {required this.invoice, required this.canManage, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = index.isOdd ? const Color(0xFFF9FAFB) : Colors.white;
    return Material(
      color: bg,
      child: InkWell(
        hoverColor: const Color(0xFFEFF6FF),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SalesInvoiceDetailPage(invoice: invoice),
        )),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 28,
                child: Text(invoice.customerName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 18,
                child: Text(_fmtDate(invoice.date),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
              Expanded(
                flex: 16,
                child: MoneyText(invoice.total,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 16,
                child: MoneyText(invoice.balance,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: invoice.balance > 0
                            ? AppColors.dangerText
                            : AppColors.successText)),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 14,
                child: _InvoiceStatusChip(status: invoice.status),
              ),
              SizedBox(
                width: 40,
                child: canManage && !invoice.isPaid && !invoice.isCancelled
                    ? _InvoiceActions(invoice: invoice)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _InvoiceActions extends ConsumerWidget {
  final SalesInvoice invoice;
  const _InvoiceActions({required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit') {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SalesInvoiceFormPage(editing: invoice),
            fullscreenDialog: true,
          ));
        } else if (v == 'cancel') {
          ref.read(salesInvoiceProvider.notifier).cancel(invoice.id);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'edit',
            child: Text('Edit', style: TextStyle(fontSize: 13))),
        const PopupMenuItem(
            value: 'cancel',
            child: Text('Cancel',
                style: TextStyle(
                    fontSize: 13, color: AppColors.dangerText))),
      ],
      child: const Icon(Icons.more_vert_rounded,
          size: 18, color: AppColors.textSecondary),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invoices — mobile list
// ─────────────────────────────────────────────────────────────────────────────

class _InvoicesMobileList extends StatelessWidget {
  final List<SalesInvoice> invoices;
  final bool canManage;
  const _InvoicesMobileList(
      {required this.invoices, required this.canManage});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: invoices.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) =>
          _InvoicesMobileRow(invoice: invoices[i], canManage: canManage),
    );
  }
}

class _InvoicesMobileRow extends ConsumerWidget {
  final SalesInvoice invoice;
  final bool canManage;
  const _InvoicesMobileRow(
      {required this.invoice, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SalesInvoiceDetailPage(invoice: invoice),
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.iconSales.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.description_outlined,
                  size: 18, color: AppColors.iconSales),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(invoice.customerName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(_fmtDate(invoice.date),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(invoice.total,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                _InvoiceStatusChip(status: invoice.status),
              ],
            ),
            if (canManage && !invoice.isPaid && !invoice.isCancelled) ...[
              const SizedBox(width: 4),
              _InvoiceActions(invoice: invoice),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _ColHead extends StatelessWidget {
  final String label;
  final bool right;
  const _ColHead({required this.label, this.right = false});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textSecondary));
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color color;
  const _StatusChip(
      {required this.label, required this.bg, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: color)),
    );
  }
}

class _InvoiceStatusChip extends StatelessWidget {
  final String status;
  const _InvoiceStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, color) = switch (status) {
      'PAID' => ('Paid', AppColors.successBg, AppColors.successText),
      'PARTIAL' => ('Partial', AppColors.navActiveBg, AppColors.primary),
      'CANCELLED' => ('Cancelled', AppColors.dangerBg, AppColors.dangerText),
      _ => ('Unpaid', AppColors.warningBg, AppColors.warningText),
    };
    return _StatusChip(label: label, bg: bg, color: color);
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool canManage;
  final VoidCallback onAdd;
  const _EmptyState({
    required this.icon,
    required this.label,
    required this.canManage,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary)),
            if (canManage) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded,
                    size: 16, color: Colors.white),
                label: const Text('Create',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.dangerText.withAlpha(80)),
      ),
      child: Text(message,
          style:
              const TextStyle(fontSize: 13, color: AppColors.dangerText)),
    );
  }
}