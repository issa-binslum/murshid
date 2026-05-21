import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/user_item_model.dart';
import '../../core/providers/user_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Permission groups shown as checkboxes (keys must match DB seeds)
// ─────────────────────────────────────────────────────────────────────────────

const _permGroups = [
  _PermGroup('Dashboard',       ['dashboard:view']),
  _PermGroup('Accounts',        ['accounts:view', 'accounts:manage']),
  _PermGroup('Sales',           ['sales:view', 'sales:manage']),
  _PermGroup('Customers',       ['customers:view', 'customers:manage']),
  _PermGroup('Purchases',       ['purchases:view', 'purchases:manage']),
  _PermGroup('Suppliers',       ['suppliers:view', 'suppliers:manage']),
  _PermGroup('Inventory',       ['inventory:view', 'inventory:manage']),
  _PermGroup('Receipts',        ['receipts:view', 'receipts:manage']),
  _PermGroup('Payments',        ['payments:view', 'payments:manage']),
  _PermGroup('Reports',         ['reports:view']),
  _PermGroup('Audit Log',       ['audit:view']),
  _PermGroup('Users & Access',  ['users:manage']),
];

class _PermGroup {
  final String label;
  final List<String> keys;
  const _PermGroup(this.label, this.keys);
}

// Friendly label for each key
const _keyLabel = <String, String>{
  'dashboard:view':    'View dashboard',
  'accounts:view':    'View accounts',
  'accounts:manage':  'Manage accounts',
  'sales:view':       'View sales',
  'sales:manage':     'Create & manage sales',
  'customers:view':   'View customers',
  'customers:manage': 'Manage customers',
  'purchases:view':   'View purchases',
  'purchases:manage': 'Create & manage purchases',
  'suppliers:view':   'View suppliers',
  'suppliers:manage': 'Manage suppliers',
  'inventory:view':   'View inventory',
  'inventory:manage': 'Manage inventory',
  'receipts:view':    'View receipts',
  'receipts:manage':  'Record receipts',
  'payments:view':    'View payments',
  'payments:manage':  'Record payments',
  'reports:view':     'View reports',
  'audit:view':       'View audit log',
  'users:manage':     'Add & manage users',
};

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class UserFormPage extends ConsumerStatefulWidget {
  final UserItem? editing;
  final List<PermissionItem> availablePermissions;

  const UserFormPage({
    super.key,
    required this.availablePermissions,
    this.editing,
  });

  @override
  ConsumerState<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends ConsumerState<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _phoneCtrl;
  late Set<String> _selectedPerms;
  late String _status;
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  // Keys actually present in the database
  late final Set<String> _validKeys;

  @override
  void initState() {
    super.initState();
    _validKeys = widget.availablePermissions.map((p) => p.key).toSet();

    final u = widget.editing;
    _fullNameCtrl = TextEditingController(text: u?.fullName ?? '');
    _emailCtrl    = TextEditingController(text: u?.email ?? '');
    _usernameCtrl = TextEditingController(text: u?.username ?? '');
    _passwordCtrl = TextEditingController();
    _phoneCtrl    = TextEditingController(text: u?.phone ?? '');
    _selectedPerms = u != null
        ? Set<String>.from(u.permissions)
        : <String>{};
    _status = u?.status ?? 'ACTIVE';
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() { _saving = true; _error = null; });

    bool ok;
    if (_isEditing) {
      ok = await ref.read(userProvider.notifier).update(
        widget.editing!.id,
        fullName:    _fullNameCtrl.text.trim(),
        email:       _emailCtrl.text.trim(),
        username:    _usernameCtrl.text.trim(),
        password:    _passwordCtrl.text.isNotEmpty ? _passwordCtrl.text : null,
        phone:       _phoneCtrl.text.trim(),
        status:      _status,
        permissions: _selectedPerms.toList(),
      );
    } else {
      ok = await ref.read(userProvider.notifier).create(
        fullName:    _fullNameCtrl.text.trim(),
        email:       _emailCtrl.text.trim(),
        username:    _usernameCtrl.text.trim(),
        password:    _passwordCtrl.text,
        phone:       _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        permissions: _selectedPerms.toList(),
        status:      _status,
      );
    }

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = ref.read(userProvider).error;
        _saving = false;
      });
      ref.read(userProvider.notifier).clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  Widget _wideLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: _cardBody(),
        ),
      ),
    );
  }

  Widget _narrowLayout() {
    return Column(
      children: [
        _Header(
          title: _isEditing ? 'Edit User' : 'Add User',
          onClose: () => Navigator.of(context).pop(),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: _formContent(),
        )),
        _Footer(
          saving: _saving,
          label: _isEditing ? 'Save Changes' : 'Add User',
          onCancel: () => Navigator.of(context).pop(),
          onSave: _submit,
        ),
      ],
    );
  }

  Widget _cardBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Header(
          title: _isEditing ? 'Edit User' : 'Add User',
          onClose: () => Navigator.of(context).pop(),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
            child: _formContent(),
          ),
        ),
        _Footer(
          saving: _saving,
          label: _isEditing ? 'Save Changes' : 'Add User',
          onCancel: () => Navigator.of(context).pop(),
          onSave: _submit,
        ),
      ],
    );
  }

  Widget _formContent() {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 18),
          ],

          // ── Personal info ──────────────────────────────────────────────
          _SectionLabel('Personal Information'),
          const SizedBox(height: 14),

          _InputField(label: 'Full Name', ctrl: _fullNameCtrl,
              hint: 'e.g. John Doe', required: true),
          const SizedBox(height: 14),

          if (isWide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: _InputField(
                  label: 'Email', ctrl: _emailCtrl,
                  hint: 'user@example.com',
                  keyboard: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _InputField(
                  label: 'Phone (optional)', ctrl: _phoneCtrl,
                  hint: '+255 700 000 000',
                  keyboard: TextInputType.phone,
                ),
              ),
            ])
          else
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _InputField(
                label: 'Email', ctrl: _emailCtrl,
                hint: 'user@example.com',
                keyboard: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _InputField(
                label: 'Phone (optional)', ctrl: _phoneCtrl,
                hint: '+255 700 000 000',
                keyboard: TextInputType.phone,
              ),
            ]),

          const SizedBox(height: 24),

          // ── Credentials ────────────────────────────────────────────────
          _SectionLabel('Account Credentials'),
          const SizedBox(height: 14),

          if (isWide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: _InputField(
                  label: 'Username', ctrl: _usernameCtrl,
                  hint: 'e.g. johndoe', required: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _PasswordField(
                  ctrl: _passwordCtrl, isEditing: _isEditing,
                  obscure: _obscure,
                  onToggle: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ])
          else
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _InputField(
                label: 'Username', ctrl: _usernameCtrl,
                hint: 'e.g. johndoe', required: true,
              ),
              const SizedBox(height: 14),
              _PasswordField(
                ctrl: _passwordCtrl, isEditing: _isEditing,
                obscure: _obscure,
                onToggle: () => setState(() => _obscure = !_obscure),
              ),
            ]),

          if (_isEditing) ...[
            const SizedBox(height: 14),
            const _FieldLabel(label: 'Status'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey(_status),
              initialValue: _status,
              decoration: _dec(hint: ''),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              items: const [
                DropdownMenuItem(value: 'ACTIVE',   child: Text('Active')),
                DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
              ],
              onChanged: (v) => setState(() => _status = v!),
            ),
          ],

          const SizedBox(height: 24),

          // ── Permissions ────────────────────────────────────────────────
          _SectionLabel('Permissions'),
          const SizedBox(height: 4),
          Text(
            'Choose what this user is allowed to do in the system.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          ..._permGroups
              .where((g) => g.keys.any(_validKeys.contains))
              .map((g) => _PermissionGroup(
                    group: g,
                    validKeys: _validKeys,
                    selectedPerms: _selectedPerms,
                    onToggle: (key, checked) => setState(() {
                      checked
                          ? _selectedPerms.add(key)
                          : _selectedPerms.remove(key);
                    }),
                    onToggleAll: (keys, selectAll) => setState(() {
                      if (selectAll) {
                        _selectedPerms.addAll(keys);
                      } else {
                        _selectedPerms.removeAll(keys);
                      }
                    }),
                  )),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Permission group widget
// ─────────────────────────────────────────────────────────────────────────────

class _PermissionGroup extends StatelessWidget {
  final _PermGroup group;
  final Set<String> validKeys;
  final Set<String> selectedPerms;
  final void Function(String key, bool checked) onToggle;
  final void Function(List<String> keys, bool selectAll) onToggleAll;

  const _PermissionGroup({
    required this.group,
    required this.validKeys,
    required this.selectedPerms,
    required this.onToggle,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    final keys = group.keys.where(validKeys.contains).toList();
    if (keys.isEmpty) return const SizedBox.shrink();

    final allSelected = keys.every(selectedPerms.contains);
    final noneSelected = keys.every((k) => !selectedPerms.contains(k));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Group header with "Select all" toggle
          InkWell(
            onTap: () => onToggleAll(keys, !allSelected),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: allSelected
                    ? AppColors.primary.withAlpha(15)
                    : const Color(0xFFF9FAFB),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
                border: const Border(
                    bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Icon(
                    allSelected
                        ? Icons.check_box_rounded
                        : noneSelected
                            ? Icons.check_box_outline_blank_rounded
                            : Icons.indeterminate_check_box_rounded,
                    size: 18,
                    color: allSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    group.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: allSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    allSelected ? 'Deselect all' : 'Select all',
                    style: TextStyle(
                      fontSize: 11,
                      color: allSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Individual permission rows
          ...keys.map((key) {
            final checked = selectedPerms.contains(key);
            final label = _keyLabel[key] ?? key;
            return InkWell(
              onTap: () => onToggle(key, !checked),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: checked,
                        onChanged: (v) => onToggle(key, v ?? false),
                        activeColor: AppColors.primary,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3)),
                        side: const BorderSide(
                            color: AppColors.textSecondary, width: 1.2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: checked
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: checked
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  const _Header({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded,
                size: 20, color: AppColors.textSecondary),
            tooltip: 'Cancel',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final bool saving;
  final String label;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  const _Footer({
    required this.saving,
    required this.label,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final cancelBtn = OutlinedButton(
      onPressed: saving ? null : onCancel,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.border),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      child: const Text('Cancel',
          style: TextStyle(fontWeight: FontWeight.w600)),
    );
    final saveBtn = ElevatedButton(
      onPressed: saving ? null : onSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        disabledBackgroundColor: AppColors.primary.withAlpha(130),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      ),
      child: saving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: isWide
          ? Row(
              children: [
                const Text(
                  'Selected permissions will take effect immediately.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                const Spacer(),
                cancelBtn,
                const SizedBox(width: 12),
                saveBtn,
              ],
            )
          : Row(
              children: [
                Expanded(child: cancelBtn),
                const SizedBox(width: 12),
                Expanded(child: saveBtn),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.textSecondary, letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
      );
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final bool required;
  final TextInputType keyboard;
  final String? Function(String?)? validator;

  const _InputField({
    required this.label, required this.ctrl, required this.hint,
    this.required = false, this.keyboard = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          decoration: _dec(hint: hint),
          validator: validator ??
              (required
                  ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                  : null),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isEditing;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.ctrl, required this.isEditing,
    required this.obscure, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(
            label: isEditing ? 'New Password (optional)' : 'Password'),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          decoration: _dec(
            hint: isEditing ? 'Leave blank to keep' : 'Min 6 characters',
            suffix: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                size: 18, color: AppColors.textSecondary,
              ),
              onPressed: onToggle,
              visualDensity: VisualDensity.compact,
            ),
          ),
          validator: (v) {
            if (!isEditing && (v == null || v.isEmpty)) {
              return 'Password is required';
            }
            if (v != null && v.isNotEmpty && v.length < 6) {
              return 'Minimum 6 characters';
            }
            return null;
          },
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.dangerText.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.dangerText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: AppColors.dangerText)),
          ),
        ],
      ),
    );
  }
}

InputDecoration _dec({required String hint, Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    isDense: true,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.dangerText)),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.dangerText, width: 1.5)),
    filled: true,
    fillColor: Colors.white,
  );
}
