import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/account_model.dart';
import '../../core/providers/account_provider.dart';
import '../../core/providers/auth_provider.dart';
import 'account_form_page.dart' show AccountFormDialog;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(accountProvider.notifier).load());
  }

  Future<void> _openForm(AccountItem? editing) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => AccountFormDialog(editing: editing),
    );
  }

  Future<void> _confirmDelete(AccountItem item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _DeleteModal(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountProvider);
    final canManage = ref.watch(authProvider).hasPermission('accounts:manage');
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 720;
    final isCompact = size.height < 500;

    return Scaffold(
      resizeToAvoidBottomInset: !isCompact,
      backgroundColor: AppColors.pageBackground,
      body: Padding(
        padding: EdgeInsets.all(isWide ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeader(
              canManage: canManage,
              onNew: () => _openForm(null),
              onRefresh: () => ref.read(accountProvider.notifier).load(),
            ),
            const SizedBox(height: 20),
            if (state.error != null)
              _ErrorBanner(
                message: state.error!,
                onRetry: () => ref.read(accountProvider.notifier).load(),
              ),
            if (state.isLoading && state.items.isEmpty)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (state.items.isEmpty && !state.isLoading)
              _EmptyState(canManage: canManage, onNew: () => _openForm(null))
            else
              Expanded(
                child: isWide
                    ? _DesktopTable(
                        items: state.items,
                        canManage: canManage,
                        onEdit: _openForm,
                        onDelete: _confirmDelete,
                      )
                    : _MobileList(
                        items: state.items,
                        canManage: canManage,
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
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 720;
    final isCompact = size.height < 500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bank or Cash Account',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  SizedBox(height: 2),
                  Text('Manage your bank, cash and wallet accounts',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
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
            if ((isWide || isCompact) && canManage) ...[
              const SizedBox(width: 8),
              _AddButton(onTap: onNew),
            ],
          ],
        ),
        if (!isWide && !isCompact && canManage) ...[
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
      label: const Text('Add Account'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
  final List<AccountItem> items;
  final bool canManage;
  final void Function(AccountItem) onEdit;
  final void Function(AccountItem) onDelete;

  const _DesktopTable(
      {required this.items,
      required this.canManage,
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
                _HeaderCell('Name', flex: 4),
                SizedBox(width: 80),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) => _DesktopRow(
                item: items[i],
                canManage: canManage,
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
  const _HeaderCell(this.label, {this.flex = 1});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.3)),
      );
}

class _DesktopRow extends StatefulWidget {
  final AccountItem item;
  final bool canManage;
  final void Function(AccountItem) onEdit;
  final void Function(AccountItem) onDelete;
  const _DesktopRow(
      {required this.item,
      required this.canManage,
      required this.onEdit,
      required this.onDelete});

  @override
  State<_DesktopRow> createState() => _DesktopRowState();
}

class _DesktopRowState extends State<_DesktopRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 56,
        color: _hovered ? const Color(0xFFF0F4FF) : Colors.white,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  _TypeIcon(type: a.type),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(a.accountName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            if (widget.canManage)
              SizedBox(
                width: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _IconBtn(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        onTap: () => widget.onEdit(a)),
                    const SizedBox(width: 4),
                    _IconBtn(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete',
                        color: AppColors.dangerText,
                        onTap: () => widget.onDelete(a)),
                  ],
                ),
              )
            else
              const SizedBox(width: 80),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile list
// ─────────────────────────────────────────────────────────────────────────────

class _MobileList extends StatelessWidget {
  final List<AccountItem> items;
  final bool canManage;
  final void Function(AccountItem) onEdit;
  final void Function(AccountItem) onDelete;

  const _MobileList(
      {required this.items,
      required this.canManage,
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
          item: items[i],
          canManage: canManage,
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ),
    );
  }
}

class _MobileRow extends StatelessWidget {
  final AccountItem item;
  final bool canManage;
  final void Function(AccountItem) onEdit;
  final void Function(AccountItem) onDelete;

  const _MobileRow(
      {required this.item,
      required this.canManage,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final a = item;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          _TypeIcon(type: a.type, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.accountName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          if (canManage)
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
                if (v == 'edit') onEdit(a);
                if (v == 'delete') onDelete(a);
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delete modal
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteModal extends ConsumerStatefulWidget {
  final AccountItem item;
  const _DeleteModal({required this.item});

  @override
  ConsumerState<_DeleteModal> createState() => _DeleteModalState();
}

class _DeleteModalState extends ConsumerState<_DeleteModal> {
  bool _deleting = false;

  Future<void> _confirm() async {
    setState(() => _deleting = true);
    final ok =
        await ref.read(accountProvider.notifier).delete(widget.item.id);
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
              const Text('Delete Account',
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
                      text: widget.item.accountName,
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
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TypeIcon extends StatelessWidget {
  final AccountType type;
  final double size;
  const _TypeIcon({required this.type, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (type) {
      AccountType.bank =>
        (AppColors.cardBlue, Icons.account_balance_rounded),
      AccountType.cash => (AppColors.cardGreen, Icons.payments_rounded),
      AccountType.mobileWallet =>
        (AppColors.cardPurple, Icons.phone_android_rounded),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: size * 0.55, color: color),
    );
  }
}

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
            const Icon(Icons.account_balance_wallet_outlined,
                size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            const Text('No accounts yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text(
              'Add a bank, cash, or wallet account to get started.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (canManage) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Account'),
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
