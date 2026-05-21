import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/account_model.dart';
import '../../core/providers/account_provider.dart';

class AccountFormDialog extends ConsumerStatefulWidget {
  final AccountItem? editing;
  const AccountFormDialog({super.key, this.editing});

  @override
  ConsumerState<AccountFormDialog> createState() =>
      _AccountFormDialogState();
}

class _AccountFormDialogState extends ConsumerState<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  AccountType _type = AccountType.bank;
  bool _saving = false;
  bool _savingAnother = false;

  bool get _isEdit => widget.editing != null;
  bool get _busy => _saving || _savingAnother;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _type = e.type;
      _nameCtrl.text = e.accountName;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save({required bool addAnother}) async {
    if (!_formKey.currentState!.validate()) return;
    if (addAnother) {
      setState(() => _savingAnother = true);
    } else {
      setState(() => _saving = true);
    }

    final notifier = ref.read(accountProvider.notifier);
    final bool ok;

    if (_isEdit) {
      ok = await notifier.update(
        widget.editing!.id,
        type: _type,
        accountName: _nameCtrl.text.trim(),
      );
    } else {
      ok = await notifier.create(
        type: _type,
        accountName: _nameCtrl.text.trim(),
      );
    }

    if (!mounted) return;

    if (ok) {
      if (addAnother) {
        // Reset form and stay open
        setState(() => _savingAnother = false);
        _nameCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account created. Add another.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            backgroundColor: AppColors.successText,
            behavior: SnackBarBehavior.floating,
            width: 320,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _saving = false;
        _savingAnother = false;
      });
      final err = ref.read(accountProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(err),
              backgroundColor: AppColors.dangerText),
        );
        ref.read(accountProvider.notifier).clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.sidebarBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEdit ? 'Edit Account' : 'Add Account',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.textSecondary,
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 20),

                // ── Name ────────────────────────────────────────────────
                const Text('Name',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  enabled: !_saving,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: _hint(),
                    hintStyle: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
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
                    errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: AppColors.dangerText)),
                    focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: AppColors.dangerText, width: 1.5)),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  onFieldSubmitted: (_) => _busy ? null : _save(addAnother: false),
                ),
                const SizedBox(height: 24),

                // ── Actions ──────────────────────────────────────────────
                Row(
                  children: [
                    
                    const Spacer(),
                    // "Create & Add Another" only on create mode
                    if (!_isEdit) ...[
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _save(addAnother: true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        child: _savingAnother
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary),
                              )
                            : const Text('Create & Add Another'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton(
                      onPressed: _busy ? null : () => _save(addAnother: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _isEdit ? 'Save' : 'Create',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
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

  String _hint() => switch (_type) {
        AccountType.cash => 'e.g. Petty Cash',
        AccountType.mobileWallet => 'e.g. Company M-Pesa',
        AccountType.bank => 'e.g. KCB Main Account',
      };
}
