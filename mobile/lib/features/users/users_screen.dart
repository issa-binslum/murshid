import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/user_item_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import 'user_detail_page.dart';
import 'user_form_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tokens
// ─────────────────────────────────────────────────────────────────────────────

const _kRowHeight = 56.0;
const _kHeaderHeight = 42.0;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(userProvider.notifier).load());
  }

  Future<void> _openForm(UserItem? editing) async {
    final state = ref.read(userProvider);
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => UserFormPage(
          editing: editing,
          availablePermissions: state.availablePermissions,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(UserItem item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _DeleteModal(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userProvider);
    final canManage = ref.watch(authProvider).hasPermission('users:manage');
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
              isWide: isWide,
              canManage: canManage,
              onNew: () => _openForm(null),
              onRefresh: () => ref.read(userProvider.notifier).load(),
            ),
            const SizedBox(height: 20),
            if (state.error != null)
              _ErrorBanner(
                message: state.error!,
                onRetry: () => ref.read(userProvider.notifier).load(),
              ),
            if (state.isLoading && state.items.isEmpty)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.items.isEmpty)
              _EmptyState(canManage: canManage, onNew: () => _openForm(null))
            else ...[
              _CountLine(count: state.items.length),
              const SizedBox(height: 12),
              Expanded(
                child: isWide
                    ? _DesktopTable(
                        items: state.items,
                        canManage: canManage,
                        onEdit: (u) => _openForm(u),
                        onDelete: _confirmDelete,
                      )
                    : _MobileList(
                        items: state.items,
                        canManage: canManage,
                        onEdit: (u) => _openForm(u),
                        onDelete: _confirmDelete,
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
// Page header
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final bool isWide;
  final bool canManage;
  final VoidCallback onNew;
  final VoidCallback onRefresh;
  const _PageHeader({
    required this.isWide,
    required this.canManage,
    required this.onNew,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Users',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Manage who has access to this business',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
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
        if (canManage) ...[
          const SizedBox(width: 8),
          _FlatButton(
            label: 'Add User',
            icon: Icons.person_add_rounded,
            onTap: onNew,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop table
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopTable extends StatelessWidget {
  final List<UserItem> items;
  final bool canManage;
  final void Function(UserItem) onEdit;
  final void Function(UserItem) onDelete;

  const _DesktopTable({
    required this.items,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            height: _kHeaderHeight,
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 16),
                _HeaderCell('Full Name', flex: 3),
                _HeaderCell('Username', flex: 2),
                _HeaderCell('Email', flex: 3),
                _HeaderCell('Permissions', flex: 2),
                _HeaderCell('Status', flex: 2),
                SizedBox(width: 88),
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
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DesktopRow extends StatefulWidget {
  final UserItem item;
  final bool canManage;
  final void Function(UserItem) onEdit;
  final void Function(UserItem) onDelete;
  const _DesktopRow(
      {required this.item, required this.canManage, required this.onEdit, required this.onDelete});

  @override
  State<_DesktopRow> createState() => _DesktopRowState();
}

class _DesktopRowState extends State<_DesktopRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => UserDetailPage(user: u),
        )),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: _kRowHeight,
        color: _hovered ? const Color(0xFFF0F4FF) : Colors.white,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Text(
                u.fullName,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '@${u.username}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                u.email,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: _PermsBadge(count: u.permissions.length, isOwner: u.isOwner),
            ),
            Expanded(
              flex: 2,
              child: _StatusBadge(active: u.isActive),
            ),
            if (widget.canManage)
              SizedBox(
                width: 88,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _IconBtn(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit',
                      onTap: () => widget.onEdit(u),
                    ),
                    const SizedBox(width: 4),
                    if (!u.isOwner)
                      _IconBtn(
                        icon: Icons.person_remove_outlined,
                        tooltip: 'Remove',
                        color: AppColors.dangerText,
                        onTap: () => widget.onDelete(u),
                      ),
                  ],
                ),
              )
            else
              const SizedBox(width: 88),
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
  final List<UserItem> items;
  final bool canManage;
  final void Function(UserItem) onEdit;
  final void Function(UserItem) onDelete;

  const _MobileList({
    required this.items,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.border),
      ),
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
  final UserItem item;
  final bool canManage;
  final void Function(UserItem) onEdit;
  final void Function(UserItem) onDelete;

  const _MobileRow({
    required this.item,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final u = item;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => UserDetailPage(user: u),
      )),
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.fullName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  '@${u.username}  ·  ${u.email}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _PermsBadge(count: u.permissions.length, isOwner: u.isOwner),
                    const SizedBox(width: 8),
                    _StatusBadge(active: u.isActive),
                  ],
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 18, color: AppColors.textSecondary),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (!u.isOwner)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Remove',
                        style: TextStyle(color: AppColors.dangerText)),
                  ),
              ],
              onSelected: (v) {
                if (v == 'edit') onEdit(u);
                if (v == 'delete') onDelete(u);
              },
            ),
        ],
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delete confirmation modal
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteModal extends ConsumerStatefulWidget {
  final UserItem item;
  const _DeleteModal({required this.item});

  @override
  ConsumerState<_DeleteModal> createState() => _DeleteModalState();
}

class _DeleteModalState extends ConsumerState<_DeleteModal> {
  bool _deleting = false;

  Future<void> _confirm() async {
    setState(() => _deleting = true);
    final ok = await ref.read(userProvider.notifier).delete(widget.item.id);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              const Text(
                'Remove User',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5),
                  children: [
                    const TextSpan(text: 'Remove '),
                    TextSpan(
                      text: widget.item.fullName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const TextSpan(
                        text:
                            ' from this business? They will lose all access.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  border: Border.all(
                      color: AppColors.dangerText.withAlpha(80)),
                ),
                child: const Text(
                  'This action cannot be undone.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.dangerText,
                      fontWeight: FontWeight.w600),
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
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Remove',
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

class _PermsBadge extends StatelessWidget {
  final int count;
  final bool isOwner;
  const _PermsBadge({required this.count, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOwner
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isOwner
              ? const Color(0xFFF59E0B)
              : const Color(0xFF93C5FD),
        ),
      ),
      child: Text(
        isOwner ? 'Owner' : '$count perm${count == 1 ? '' : 's'}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isOwner
              ? const Color(0xFF92400E)
              : const Color(0xFF1D4ED8),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? AppColors.successBg : AppColors.dangerBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active ? AppColors.successText : AppColors.dangerText,
        ),
      ),
    );
  }
}

class _CountLine extends StatelessWidget {
  final int count;
  const _CountLine({required this.count});

  @override
  Widget build(BuildContext context) => Text(
        '$count user${count == 1 ? '' : 's'}',
        style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500),
      );
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
            const Icon(Icons.group_outlined,
                size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            const Text(
              'No users yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add users to give them access to this business.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (canManage) ...[
              const SizedBox(height: 20),
              _FlatButton(
                  label: 'Add First User',
                  icon: Icons.person_add_rounded,
                  onTap: onNew),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        border: Border.all(color: AppColors.dangerText.withAlpha(80)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.dangerText,
                  fontWeight: FontWeight.w500),
            ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

class _FlatButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _FlatButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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

