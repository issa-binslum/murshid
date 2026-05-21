import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/account_model.dart';
import '../../core/models/purchase_model.dart';
import '../../core/models/supplier_model.dart';
import '../../core/providers/account_provider.dart';
import '../../core/providers/payment_provider.dart';
import '../../core/providers/purchase_provider.dart';
import '../../core/providers/supplier_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class PaymentFormPage extends ConsumerStatefulWidget {
  final PurchaseInvoice? fromInvoice;
  const PaymentFormPage({super.key, this.fromInvoice});

  @override
  ConsumerState<PaymentFormPage> createState() => _PaymentFormPageState();
}

class _PaymentFormPageState extends ConsumerState<PaymentFormPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  String? _accountId;
  String? _supplierId;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final fi = widget.fromInvoice;
    if (fi != null) {
      _supplierId = fi.supplierId;
      final t = fi.total;
      _amountCtrl.text = t == t.truncateToDouble()
          ? t.toInt().toString()
          : t.toStringAsFixed(2);
      _descCtrl.text = fi.description ?? '';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accountProvider.notifier).load();
      ref.read(supplierProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  bool _validate() {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (_accountId == null) {
      setState(() => _error = 'Please select the account to pay from.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final amount = double.parse(_amountCtrl.text.replaceAll(',', ''));
    final suppliers = ref.read(supplierProvider).items;
    final payeeName = _supplierId != null
        ? suppliers.where((s) => s.id == _supplierId).firstOrNull?.name
        : null;
    final ok = await ref.read(paymentProvider.notifier).create(
          date: _date,
          accountId: _accountId!,
          amount: amount,
          payee: payeeName,
          supplierId: _supplierId,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
        );

    if (!mounted) return;
    if (ok) {
      // Refresh purchase invoices so status changes are visible immediately
      ref.read(purchaseInvoiceProvider.notifier).load();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(_snack('Payment recorded.'));
    } else {
      _handleError();
    }
  }

  Future<void> _submitAndAddAnother() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final amount = double.parse(_amountCtrl.text.replaceAll(',', ''));
    final suppliers = ref.read(supplierProvider).items;
    final payeeName = _supplierId != null
        ? suppliers.where((s) => s.id == _supplierId).firstOrNull?.name
        : null;
    final ok = await ref.read(paymentProvider.notifier).create(
          date: _date,
          accountId: _accountId!,
          amount: amount,
          payee: payeeName,
          supplierId: _supplierId,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
        );

    if (!mounted) return;
    if (ok) {
      // Refresh purchase invoices so status changes are visible immediately
      ref.read(purchaseInvoiceProvider.notifier).load();
      _formKey.currentState?.reset();
      setState(() {
        _supplierId = null;
        _accountId = null;
        _amountCtrl.clear();
        _descCtrl.clear();
        _date = DateTime.now();
        _saving = false;
        _error = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(_snack('Payment recorded. Ready for next entry.'));
    } else {
      _handleError();
    }
  }

  void _handleError() {
    final err = ref.read(paymentProvider).error ?? 'An error occurred.';
    ref.read(paymentProvider.notifier).clearError();
    String display = err;
    if (err.contains('insufficient_funds') ||
        err.toLowerCase().contains('insufficient')) {
      display = 'Insufficient funds in the selected account.';
    }
    setState(() {
      _saving = false;
      _error = display;
    });
  }

  SnackBar _snack(String msg) => SnackBar(
        content: Text(msg,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
        backgroundColor: AppColors.successText,
        behavior: SnackBarBehavior.floating,
        width: 320,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

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
        constraints: const BoxConstraints(maxWidth: 560),
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
        _Header(onClose: () => Navigator.of(context).pop()),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: _formContent(),
          ),
        ),
        _Footer(
          saving: _saving,
          onSave: _submit,
          onSaveAndAdd: _submitAndAddAnother,
        ),
      ],
    );
  }

  Widget _cardBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Header(onClose: () => Navigator.of(context).pop()),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
            child: _formContent(),
          ),
        ),
        _Footer(
          saving: _saving,
          onSave: _submit,
          onSaveAndAdd: _submitAndAddAnother,
        ),
      ],
    );
  }

  Widget _formContent() {
    final accounts = ref.watch(accountProvider).items;
    final supplierState = ref.watch(supplierProvider);
    final suppliers = supplierState.items;
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

          _SectionLabel('Payment Info'),
          const SizedBox(height: 14),

          if (isWide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _datePicker()),
              const SizedBox(width: 14),
              Expanded(
                  child: _supplierDropdown(
                      suppliers, supplierState.isLoading)),
            ])
          else
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _datePicker(),
              const SizedBox(height: 14),
              _supplierDropdown(suppliers, supplierState.isLoading),
            ]),

          const SizedBox(height: 14),
          _FieldLabel('Paid From (Account)'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _accountId,
            decoration: _dec(hint: 'Select account'),
            isExpanded: true,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textPrimary),
            items: accounts
                .map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(
                        _accountLabel(a),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _accountId = v),
            validator: (v) =>
                v == null ? 'Select an account' : null,
          ),

          const SizedBox(height: 14),
          _FieldLabel('Amount'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            ],
            style: const TextStyle(
                fontSize: 13, color: AppColors.textPrimary),
            decoration: _dec(hint: '0.00'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter amount';
              final n = double.tryParse(v.replaceAll(',', ''));
              if (n == null || n <= 0) return 'Enter a valid amount';
              return null;
            },
          ),

          const SizedBox(height: 14),
          _FieldLabel('Description (optional)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descCtrl,
            maxLines: 2,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textPrimary),
            decoration: _dec(hint: 'Notes about this payment…'),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _datePicker() {
    final label =
        '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Date'),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _supplierDropdown(List<Supplier> suppliers, bool loading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Payee / Supplier (optional)'),
        const SizedBox(height: 6),
        if (loading && suppliers.isEmpty)
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.textSecondary),
                ),
                SizedBox(width: 8),
                Text('Loading suppliers…',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _supplierId,
            decoration: _dec(hint: 'Select supplier (optional)'),
            isExpanded: true,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textPrimary),
            items: suppliers
                .map((s) => DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(s.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _supplierId = v),
          ),
      ],
    );
  }

  String _accountLabel(AccountItem a) {
    final parts = [a.accountName];
    if (a.bankName != null) parts.add(a.bankName!);
    if (a.accountNumber != null) parts.add(a.accountNumber!);
    return parts.join(' · ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

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
          const Text('New Payment',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded,
                size: 20, color: AppColors.textSecondary),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onSaveAndAdd;
  const _Footer({
    required this.saving,
    required this.onSave,
    required this.onSaveAndAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final saveBtn = ElevatedButton(
      onPressed: saving ? null : onSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        disabledBackgroundColor: AppColors.primary.withAlpha(130),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      child: saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Text('Record Payment',
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: isWide
          ? Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onSaveAndAdd,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Record & Add Another',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: saveBtn),
            ])
          : Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: double.infinity, child: saveBtn),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: saving ? null : onSaveAndAdd,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Record & Add Another',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.dangerText.withAlpha(80)),
      ),
      child: Text(message,
          style: const TextStyle(
              fontSize: 13, color: AppColors.dangerText)),
    );
  }
}

InputDecoration _dec({required String hint}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          fontSize: 13, color: AppColors.textSecondary),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          borderSide: const BorderSide(
              color: AppColors.dangerText, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
              color: AppColors.dangerText, width: 1.5)),
    );
