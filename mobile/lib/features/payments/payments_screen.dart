import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/account_model.dart';
import '../../core/models/payment_model.dart';
import '../../core/providers/account_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/payment_provider.dart';
import '../../core/widgets/money_text.dart';
import 'payment_detail_page.dart';
import 'payment_form_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(paymentProvider.notifier).load();
      ref.read(accountProvider.notifier).load();
    });
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Payment> _filtered(List<Payment> items, List<AccountItem> accounts) {
    if (_query.isEmpty) return items;
    return items.where((p) {
      if (p.payee?.toLowerCase().contains(_query) ?? false) return true;
      if (p.description?.toLowerCase().contains(_query) ?? false) return true;
      final acct = accounts.where((a) => a.id == p.accountId).firstOrNull;
      if (acct?.accountName.toLowerCase().contains(_query) ?? false) {
        return true;
      }
      return _fmtDate(p.date).toLowerCase().contains(_query);
    }).toList();
  }

  Future<void> _openForm() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PaymentFormPage()),
    );
  }

  Future<void> _confirmDelete(
      Payment payment, List<AccountItem> accounts) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _DeleteModal(payment: payment, accounts: accounts),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentProvider);
    final accounts = ref.watch(accountProvider).items;
    final canManage =
        ref.watch(authProvider).hasPermission('payments:manage');
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final filtered = _filtered(state.items, accounts);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Padding(
        padding: EdgeInsets.all(isWide ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeader(
              canManage: canManage,
              onNew: _openForm,
              onRefresh: () => ref.read(paymentProvider.notifier).load(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by payee, description or account…',
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
                onRetry: () => ref.read(paymentProvider.notifier).load(),
              ),
            if (state.isLoading && state.items.isEmpty)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (state.items.isEmpty && !state.isLoading)
              _EmptyState(canManage: canManage, onNew: _openForm)
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
                        accounts: accounts,
                        onDelete: (p) => _confirmDelete(p, accounts),
                      )
                    : _MobileList(
                        canManage: canManage,
                        items: filtered,
                        accounts: accounts,
                        onDelete: (p) => _confirmDelete(p, accounts),
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
                  Text('Payments',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  SizedBox(height: 2),
                  Text('Track outgoing payments from accounts',
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
          SizedBox(width: double.infinity, child: _AddButton(onTap: onNew)),
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
      label: const Text('New Payment'),
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
  final List<Payment> items;
  final List<AccountItem> accounts;
  final void Function(Payment) onDelete;

  const _DesktopTable(
      {required this.canManage,
      required this.items,
      required this.accounts,
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
              color: Color(0xFFECEEF2),
              border:
                  Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 16),
                _HeaderCell('Date', flex: 2),
                _HeaderCell('Payee', flex: 2),
                _HeaderCell('Paid From', flex: 3),
                _HeaderCell('Description', flex: 3),
                _HeaderCell('Amount', flex: 2),
                _HeaderCell('Action', flex: 1, center: true),
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
                payment: items[i],
                accounts: accounts,
                canManage: canManage,
                index: i,
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
  final bool center;
  const _HeaderCell(this.label, {this.flex = 1, this.center = false});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(label,
            textAlign: center ? TextAlign.center : TextAlign.left,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.3)),
      );
}

class _DesktopRow extends StatelessWidget {
  final Payment payment;
  final List<AccountItem> accounts;
  final bool canManage;
  final int index;
  final void Function(Payment) onDelete;

  const _DesktopRow({
    required this.payment,
    required this.accounts,
    required this.canManage,
    required this.index,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final acct = accounts.where((a) => a.id == p.accountId).firstOrNull;
    final bg = index.isOdd ? const Color(0xFFF9FAFB) : Colors.white;

    return Material(
      color: bg,
      child: InkWell(
        hoverColor: const Color(0xFFEFF6FF),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => PaymentDetailPage(payment: p)),
        ),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Text(
                  _fmtDate(p.date),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  p.payee ?? '—',
                  style: TextStyle(
                      fontSize: 13,
                      color: p.payee != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  acct?.accountName ?? '—',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  p.description ?? '—',
                  style: TextStyle(
                      fontSize: 13,
                      color: p.description != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: MoneyText(
                  p.amount,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.iconPayments),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 1,
                child: canManage
                    ? Center(
                        child: _IconBtn(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Delete',
                          color: AppColors.dangerText,
                          onTap: () => onDelete(p),
                        ),
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
  final List<Payment> items;
  final List<AccountItem> accounts;
  final void Function(Payment) onDelete;

  const _MobileList(
      {required this.canManage,
      required this.items,
      required this.accounts,
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
          payment: items[i],
          accounts: accounts,
          onDelete: onDelete,
        ),
      ),
    );
  }
}

class _MobileRow extends StatelessWidget {
  final bool canManage;
  final Payment payment;
  final List<AccountItem> accounts;
  final void Function(Payment) onDelete;

  const _MobileRow(
      {required this.canManage,
      required this.payment,
      required this.accounts,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final acct = accounts.where((a) => a.id == p.accountId).firstOrNull;
    final acctLabel = acct?.accountName ?? '—';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => PaymentDetailPage(payment: p)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.iconPayments.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.payments_outlined,
                  size: 20, color: AppColors.iconPayments),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.payee ?? acctLabel,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_fmtDate(p.date)} · $acctLabel',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.iconPayments.withAlpha(15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: MoneyText(
                p.amount,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.iconPayments),
              ),
            ),
            if (canManage) ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    size: 18, color: AppColors.textSecondary),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style:
                            TextStyle(color: AppColors.dangerText)),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'delete') onDelete(p);
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
  final Payment payment;
  final List<AccountItem> accounts;
  const _DeleteModal({required this.payment, required this.accounts});

  @override
  ConsumerState<_DeleteModal> createState() => _DeleteModalState();
}

class _DeleteModalState extends ConsumerState<_DeleteModal> {
  bool _deleting = false;

  Future<void> _confirm() async {
    setState(() => _deleting = true);
    final ok =
        await ref.read(paymentProvider.notifier).delete(widget.payment.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acct = widget.accounts
        .where((a) => a.id == widget.payment.accountId)
        .firstOrNull;
    final label =
        widget.payment.payee ?? acct?.accountName ?? 'this payment';

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
              const Text('Delete Payment',
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
            const Icon(Icons.payments_outlined,
                size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            const Text('No payments yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text(
              'Record your first payment to get started.',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (canManage) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New Payment'),
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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} / '
    '${d.month.toString().padLeft(2, '0')} / '
    '${d.year}';
