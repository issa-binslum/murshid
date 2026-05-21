import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/user_item_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import 'user_form_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class UserDetailPage extends ConsumerWidget {
  final UserItem user;
  const UserDetailPage({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userProvider);
    final live = state.items.firstWhere((u) => u.id == user.id,
        orElse: () => user);
    final canManage =
        ref.watch(authProvider).hasPermission('users:manage');
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWide ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeader(
              user: live,
              canManage: canManage,
              isWide: isWide,
              onBack: () => Navigator.of(context).pop(),
              onEdit: () async {
                final s = ref.read(userProvider);
                await Navigator.of(context).push(
                  MaterialPageRoute<bool>(
                    fullscreenDialog: true,
                    builder: (_) => UserFormPage(
                      editing: live,
                      availablePermissions: s.availablePermissions,
                    ),
                  ),
                );
              },
              onRemove: (canManage && !live.isOwner)
                  ? () => _showDeleteDialog(context, ref, live)
                  : null,
            ),
            const SizedBox(height: 24),
            _UserCard(user: live),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, UserItem u) {
    showDialog<void>(
      context: context,
      builder: (_) => _DeleteDialog(
        user: u,
        onDeleted: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page header — breadcrumb + title + action buttons
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final UserItem user;
  final bool canManage;
  final bool isWide;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  const _PageHeader({
    required this.user,
    required this.canManage,
    required this.isWide,
    required this.onBack,
    required this.onEdit,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = [
      if (canManage) ...[
        _ActionBtn(
            label: 'Edit', icon: Icons.edit_outlined, onTap: onEdit),
        if (onRemove != null)
          _ActionBtn(
            label: 'Remove',
            icon: Icons.person_remove_outlined,
            color: AppColors.dangerText,
            onTap: onRemove!,
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
              child: const Text('Users',
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
                user.fullName,
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
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusBadge(active: user.isActive),
                      if (user.isOwner) ...[
                        const SizedBox(width: 6),
                        _OwnerBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@${user.username}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
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
// Unified user card
// ─────────────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final UserItem user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final u = user;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Account info ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: identity fields
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field('Full Name', u.fullName),
                      const SizedBox(height: 12),
                      _field('Username', '@${u.username}'),
                      const SizedBox(height: 12),
                      _field('Email', u.email),
                      if (u.phone != null && u.phone!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _field('Phone', u.phone!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Right: role + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field('Role', u.isOwner ? 'Owner' : 'Member',
                          valueColor: u.isOwner
                              ? const Color(0xFF92400E)
                              : AppColors.textPrimary),
                      const SizedBox(height: 12),
                      const Text('Status',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      _StatusBadge(active: u.isActive),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Permissions ───────────────────────────────────────────────
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Permissions',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const Spacer(),
                    Text(
                      u.isOwner
                          ? 'All permissions'
                          : '${u.permissions.length} granted',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (u.isOwner)
                  _OwnerAllPermsNote()
                else if (u.permissions.isEmpty)
                  const Text('No permissions assigned.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: u.permissions
                        .map((p) => _PermChip(perm: p))
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _field(String label, String value,
          {Color? valueColor}) =>
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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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
// Badges
// ─────────────────────────────────────────────────────────────────────────────

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
            color: active ? AppColors.successText : AppColors.dangerText),
      ),
    );
  }
}

class _OwnerBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: const Text('Owner',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF92400E))),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Permissions helpers
// ─────────────────────────────────────────────────────────────────────────────

class _OwnerAllPermsNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
      ),
      child: const Text(
        'Owner has full access to all features and settings.',
        style: TextStyle(
            fontSize: 13,
            color: Color(0xFF92400E),
            fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _PermChip extends StatelessWidget {
  final String perm;
  const _PermChip({required this.perm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Text(perm,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D4ED8))),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delete dialog
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteDialog extends ConsumerStatefulWidget {
  final UserItem user;
  final VoidCallback onDeleted;
  const _DeleteDialog({required this.user, required this.onDeleted});

  @override
  ConsumerState<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends ConsumerState<_DeleteDialog> {
  bool _deleting = false;

  Future<void> _confirm() async {
    setState(() => _deleting = true);
    final ok =
        await ref.read(userProvider.notifier).delete(widget.user.id);
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
                    child: const Icon(Icons.person_remove_outlined,
                        size: 18, color: AppColors.dangerText),
                  ),
                  const SizedBox(width: 12),
                  const Text('Remove User',
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
                    const TextSpan(text: 'Remove '),
                    TextSpan(
                      text: widget.user.fullName,
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
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.dangerText.withAlpha(80)),
                ),
                child: const Text('This action cannot be undone.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.dangerText,
                        fontWeight: FontWeight.w600)),
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
                        : const Text('Remove',
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
