import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/auth_response_model.dart';
import '../../core/models/business_detail_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/business_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class BusinessesScreen extends ConsumerStatefulWidget {
  const BusinessesScreen({super.key});

  @override
  ConsumerState<BusinessesScreen> createState() => _BusinessesScreenState();
}

class _BusinessesScreenState extends ConsumerState<BusinessesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(businessProvider.notifier).load());
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<BusinessDetail> _filtered(List<BusinessDetail> items) {
    if (_query.isEmpty) return items;
    return items
        .where((b) => b.name.toLowerCase().contains(_query))
        .toList();
  }

  Future<void> _openAdd() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BusinessFormDialog(
        existing: null,
        onSaved: (name) async {
          final notifier = ref.read(businessProvider.notifier);
          final authNotifier = ref.read(authProvider.notifier);
          final created = await notifier.create(
            name: name,
            currency: 'USD',
            type: null,
            address: null,
            phone: null,
            email: null,
          );
          if (created != null && mounted) {
            authNotifier.addBusiness(BusinessItem(
              businessId: created.id,
              businessName: created.name,
              roleId: '',
              roleName: created.role,
              isOwner: true,
              currency: created.currency,
            ));
            _showSnack('${created.name} created', isSuccess: true);
          }
        },
      ),
    );
  }

  Future<void> _openEdit(BusinessDetail b) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BusinessFormDialog(
        existing: b,
        onSaved: (name) async {
          final ok = await ref.read(businessProvider.notifier).update(
                b.id,
                name: name,
                currency: b.currency,
                type: b.type,
                address: b.address,
                phone: b.phone,
                email: b.email,
              );
          if (ok && mounted) _showSnack('$name updated', isSuccess: true);
        },
      ),
    );
  }

  Future<void> _confirmDelete(BusinessDetail b) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _DeleteModal(
        business: b,
        onConfirm: () async {
          final ok =
              await ref.read(businessProvider.notifier).delete(b.id);
          if (ok && mounted) {
            ref.read(authProvider.notifier).removeBusiness(b.id);
            _showSnack('${b.name} deleted', isSuccess: false);
          }
        },
      ),
    );
  }

  void _showSnack(String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        backgroundColor:
            isSuccess ? AppColors.successText : AppColors.dangerText,
        behavior: SnackBarBehavior.floating,
        width: 320,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessProvider);
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 720;
    final isCompact = size.height < 500;
    final filtered = _filtered(state.items);

    return Scaffold(
      resizeToAvoidBottomInset: !isCompact,
      backgroundColor: AppColors.pageBackground,
      body: Padding(
        padding: EdgeInsets.all(isWide ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            _PageHeader(
              onNew: _openAdd,
              onRefresh: () => ref.read(businessProvider.notifier).load(),
            ),
            const SizedBox(height: 16),

            // ── Search ───────────────────────────────────────────────
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search businesses…',
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

            // ── Error banner ─────────────────────────────────────────
            if (state.error != null)
              _ErrorBanner(
                message: state.error!,
                onRetry: () =>
                    ref.read(businessProvider.notifier).load(),
              ),

            // ── Body ─────────────────────────────────────────────────
            if (state.isLoading && state.items.isEmpty)
              const Expanded(
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (state.items.isEmpty && !state.isLoading)
              _EmptyState(onNew: _openAdd)
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
                        items: filtered,
                        onEdit: _openEdit,
                        onDelete: _confirmDelete,
                      )
                    : _MobileList(
                        items: filtered,
                        onEdit: _openEdit,
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
  final VoidCallback onNew;
  final VoidCallback onRefresh;
  const _PageHeader({required this.onNew, required this.onRefresh});

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
                  Text(
                    'Businesses',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Create and manage your businesses',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
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
            if (isWide || isCompact) ...[
              const SizedBox(width: 8),
              _AddButton(onTap: onNew),
            ],
          ],
        ),
        if (!isWide && !isCompact) ...[
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
      label: const Text('New Business'),
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
  final List<BusinessDetail> items;
  final void Function(BusinessDetail) onEdit;
  final void Function(BusinessDetail) onDelete;

  const _DesktopTable({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

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
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 16),
                _HeaderCell('Business', flex: 4),
                _HeaderCell('Role', flex: 2),
                _HeaderCell('Currency', flex: 1),
                _HeaderCell('Created', flex: 2),
                SizedBox(width: 80),
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
                business: items[i],
                index: i,
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

class _DesktopRow extends StatefulWidget {
  final BusinessDetail business;
  final int index;
  final void Function(BusinessDetail) onEdit;
  final void Function(BusinessDetail) onDelete;

  const _DesktopRow({
    required this.business,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DesktopRow> createState() => _DesktopRowState();
}

class _DesktopRowState extends State<_DesktopRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.business;
    final baseBg =
        widget.index.isOdd ? const Color(0xFFF9FAFB) : Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 56,
        color: _hovered ? const Color(0xFFEFF6FF) : baseBg,
        child: Row(
          children: [
            const SizedBox(width: 16),

            // Business name + avatar
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  _InitialsAvatar(name: b.name),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Role badge
            Expanded(
              flex: 2,
              child: _RoleBadge(
                  label: b.isOwner ? 'Owner' : b.role,
                  isOwner: b.isOwner),
            ),

            // Currency
            Expanded(
              flex: 1,
              child: Text(
                b.currency,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ),

            // Created
            Expanded(
              flex: 2,
              child: Text(
                _fmtDate(b.createdAt),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),

            // Actions (owner only)
            SizedBox(
              width: 80,
              child: b.isOwner
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _IconBtn(
                          icon: Icons.edit_outlined,
                          tooltip: 'Edit',
                          onTap: () => widget.onEdit(b),
                        ),
                        const SizedBox(width: 4),
                        _IconBtn(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Delete',
                          color: AppColors.dangerText,
                          onTap: () => widget.onDelete(b),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(width: 16),
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
  final List<BusinessDetail> items;
  final void Function(BusinessDetail) onEdit;
  final void Function(BusinessDetail) onDelete;

  const _MobileList({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, i) => _MobileRow(
          business: items[i],
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ),
    );
  }
}

class _MobileRow extends StatelessWidget {
  final BusinessDetail business;
  final void Function(BusinessDetail) onEdit;
  final void Function(BusinessDetail) onDelete;

  const _MobileRow({
    required this.business,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final b = business;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _InitialsAvatar(name: b.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _RoleBadge(
                        label: b.isOwner ? 'Owner' : b.role,
                        isOwner: b.isOwner),
                    const SizedBox(width: 8),
                    Text(
                      b.currency,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (b.isOwner)
            PopupMenuButton<String>(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.border),
              ),
              icon: const Icon(Icons.more_vert_rounded,
                  size: 18, color: AppColors.textSecondary),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(color: AppColors.dangerText)),
                ),
              ],
              onSelected: (v) {
                if (v == 'edit') onEdit(b);
                if (v == 'delete') onDelete(b);
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form dialog
// ─────────────────────────────────────────────────────────────────────────────

class _BusinessFormDialog extends StatefulWidget {
  final BusinessDetail? existing;
  final Future<void> Function(String name) onSaved;

  const _BusinessFormDialog({this.existing, required this.onSaved});

  @override
  State<_BusinessFormDialog> createState() => _BusinessFormDialogState();
}

class _BusinessFormDialogState extends State<_BusinessFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSaved(_nameCtrl.text.trim());
    if (mounted) Navigator.of(context).pop();
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
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  _isEdit ? 'Edit Business' : 'New Business',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEdit
                      ? 'Update the name of your business.'
                      : 'Give your business a name to get started.',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),

                // Field label
                const Text(
                  'Business Name',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),

                // Name field
                TextFormField(
                  controller: _nameCtrl,
                  autofocus: true,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Acme Trading Co.',
                    hintStyle: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
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
                    errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: AppColors.dangerText)),
                    focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: AppColors.dangerText, width: 1.5)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Business name is required'
                      : null,
                ),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              _isEdit ? 'Save Changes' : 'Create',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delete modal
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteModal extends StatefulWidget {
  final BusinessDetail business;
  final Future<void> Function() onConfirm;
  const _DeleteModal({required this.business, required this.onConfirm});

  @override
  State<_DeleteModal> createState() => _DeleteModalState();
}

class _DeleteModalState extends State<_DeleteModal> {
  bool _deleting = false;

  Future<void> _confirm() async {
    setState(() => _deleting = true);
    await widget.onConfirm();
    if (mounted) Navigator.of(context).pop();
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
              const Text(
                'Delete Business',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dangerText,
                ),
              ),
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
                      text: '"${widget.business.name}"',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const TextSpan(
                        text:
                            '? All accounts, transactions and reports will be permanently removed. This cannot be undone.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _deleting ? null : () => Navigator.of(context).pop(),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
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
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onNew;
  const _EmptyState({required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_outlined,
                size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            const Text(
              'No businesses yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Create your first business to get started.',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New Business'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InitialsAvatar extends StatelessWidget {
  final String name;
  const _InitialsAvatar({required this.name});

  static const _bgs = [
    Color(0xFFDCE8FD), Color(0xFFD9F0E8),
    Color(0xFFFDE8DC), Color(0xFFECDCFD), Color(0xFFFDF5DC),
  ];
  static const _fgs = [
    Color(0xFF1E4BAD), Color(0xFF0D6E4A),
    Color(0xFFAD3E1E), Color(0xFF6B1EAD), Color(0xFFAD891E),
  ];

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final idx = name.length % _bgs.length;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _bgs[idx],
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _fgs[idx]),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final bool isOwner;
  const _RoleBadge({required this.label, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final bg = isOwner
        ? AppColors.navActiveBg
        : const Color(0xFFF3F4F6);
    final fg = isOwner ? AppColors.primary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: isOwner ? AppColors.primary.withAlpha(60) : AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: fg),
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

// ─────────────────────────────────────────────────────────────────────────────
// Date helper
// ─────────────────────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} / '
    '${d.month.toString().padLeft(2, '0')} / '
    '${d.year}';
