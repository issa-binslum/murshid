import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/customer_model.dart';
import '../../core/providers/customer_provider.dart';

class CustomerFormDialog extends ConsumerStatefulWidget {
  final Customer? editing;
  const CustomerFormDialog({super.key, this.editing});

  @override
  ConsumerState<CustomerFormDialog> createState() =>
      _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _billing;
  late final TextEditingController _delivery;
  late final TextEditingController _credit;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _name = TextEditingController(text: e?.name ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _billing = TextEditingController(text: e?.billingAddress ?? '');
    _delivery = TextEditingController(text: e?.deliveryAddress ?? '');
    _credit = TextEditingController(
      text: e != null && e.creditLimit > 0
          ? e.creditLimit.toStringAsFixed(
              e.creditLimit == e.creditLimit.truncateToDouble() ? 0 : 2)
          : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _billing.dispose();
    _delivery.dispose();
    _credit.dispose();
    super.dispose();
  }

  Future<void> _submit({bool addAnother = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final creditLimit = double.tryParse(_credit.text.trim()) ?? 0;

    bool ok;
    if (_isEdit) {
      ok = await ref.read(customerProvider.notifier).update(
            widget.editing!.id,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            billingAddress: _billing.text.trim(),
            deliveryAddress: _delivery.text.trim(),
            creditLimit: creditLimit,
          );
    } else {
      ok = await ref.read(customerProvider.notifier).create(
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            billingAddress: _billing.text.trim(),
            deliveryAddress: _delivery.text.trim(),
            creditLimit: creditLimit,
          );
    }

    if (!mounted) return;
    if (!ok) {
      final err = ref.read(customerProvider).error ?? 'An error occurred';
      ref.read(customerProvider.notifier).clearError();
      setState(() {
        _saving = false;
        _error = err;
      });
      return;
    }

    if (addAnother) {
      _name.clear();
      _phone.clear();
      _email.clear();
      _billing.clear();
      _delivery.clear();
      _credit.clear();
      setState(() {
        _saving = false;
        _error = null;
      });
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    return Dialog(
      backgroundColor: AppColors.sidebarBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 20,
        vertical: 40,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? 'Edit Customer' : 'New Customer',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.dangerBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                      AppColors.dangerText.withAlpha(80)),
                            ),
                            child: Text(_error!,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.dangerText)),
                          ),
                          const SizedBox(height: 14),
                        ],
                        // Name — full width
                        _Field(
                          label: 'Name',
                          controller: _name,
                          hint: 'e.g. Amina Hassan',
                          required: true,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Name is required'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        // Phone + Email
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: _Field(
                                      label: 'Phone',
                                      controller: _phone,
                                      hint: '+255 700 000 000',
                                      keyboardType: TextInputType.phone)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _Field(
                                      label: 'Email',
                                      controller: _email,
                                      hint: 'customer@example.com',
                                      keyboardType:
                                          TextInputType.emailAddress,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return null;
                                        }
                                        final ok = RegExp(
                                                r'^[^@]+@[^@]+\.[^@]+$')
                                            .hasMatch(v.trim());
                                        return ok
                                            ? null
                                            : 'Enter a valid email';
                                      })),
                            ],
                          )
                        else ...[
                          _Field(
                              label: 'Phone',
                              controller: _phone,
                              hint: '+255 700 000 000',
                              keyboardType: TextInputType.phone),
                          const SizedBox(height: 14),
                          _Field(
                              label: 'Email',
                              controller: _email,
                              hint: 'customer@example.com',
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return null;
                                }
                                final ok =
                                    RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                                        .hasMatch(v.trim());
                                return ok ? null : 'Enter a valid email';
                              }),
                        ],
                        const SizedBox(height: 14),
                        // Billing + Delivery address
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: _Field(
                                      label: 'Billing Address',
                                      controller: _billing,
                                      hint: 'e.g. P.O. Box 123, Dar es Salaam',
                                      maxLines: 2)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _Field(
                                      label: 'Delivery Address',
                                      controller: _delivery,
                                      hint: 'Leave blank if same as billing',
                                      maxLines: 2)),
                            ],
                          )
                        else ...[
                          _Field(
                              label: 'Billing Address',
                              controller: _billing,
                              hint: 'e.g. P.O. Box 123, Dar es Salaam',
                              maxLines: 2),
                          const SizedBox(height: 14),
                          _Field(
                              label: 'Delivery Address',
                              controller: _delivery,
                              hint: 'Leave blank if same as billing',
                              maxLines: 2),
                        ],
                        const SizedBox(height: 14),
                        // Credit Limit
                        _Field(
                          label: 'Credit Limit',
                          controller: _credit,
                          hint: '0',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'))
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
              // Buttons
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _submit(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_isEdit ? 'Save Changes' : 'Create Customer'),
                ),
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => _submit(addAnother: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Create & Add Another'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool required;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.required = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            children: [
              if (required)
                const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.dangerText)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: AppColors.dangerText)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: AppColors.dangerText, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
