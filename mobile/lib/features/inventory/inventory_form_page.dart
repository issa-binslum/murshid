import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/inventory_model.dart';
import '../../core/providers/inventory_provider.dart';

class InventoryFormDialog extends ConsumerStatefulWidget {
  final InventoryItem? editing;
  const InventoryFormDialog({super.key, this.editing});

  @override
  ConsumerState<InventoryFormDialog> createState() =>
      _InventoryFormDialogState();
}

class _InventoryFormDialogState
    extends ConsumerState<InventoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController();
  final _salesPriceCtrl = TextEditingController();
  final _lowStockCtrl = TextEditingController();
  final _openingQtyCtrl = TextEditingController();

  bool _saving = false;
  bool _savingAnother = false;

  bool get _isEdit => widget.editing != null;
  bool get _busy => _saving || _savingAnother;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _codeCtrl.text = e.itemCode;
      _nameCtrl.text = e.itemName;
      _unitCtrl.text = e.unitName;
      _purchasePriceCtrl.text =
          e.purchasePrice == 0 ? '' : e.purchasePrice.toString();
      _salesPriceCtrl.text =
          e.salesPrice == 0 ? '' : e.salesPrice.toString();
      _lowStockCtrl.text =
          e.lowStockLevel == 0 ? '' : e.lowStockLevel.toString();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _salesPriceCtrl.dispose();
    _lowStockCtrl.dispose();
    _openingQtyCtrl.dispose();
    super.dispose();
  }

  double _parseNum(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save({required bool addAnother}) async {
    if (!_formKey.currentState!.validate()) return;
    if (addAnother) {
      setState(() => _savingAnother = true);
    } else {
      setState(() => _saving = true);
    }

    final notifier = ref.read(inventoryProvider.notifier);
    final bool ok;

    if (_isEdit) {
      ok = await notifier.update(
        widget.editing!.id,
        itemCode: _codeCtrl.text.trim(),
        itemName: _nameCtrl.text.trim(),
        unitName: _unitCtrl.text.trim(),
        purchasePrice: _parseNum(_purchasePriceCtrl),
        salesPrice: _parseNum(_salesPriceCtrl),
        lowStockLevel: _parseNum(_lowStockCtrl),
      );
    } else {
      ok = await notifier.create(
        itemCode: _codeCtrl.text.trim(),
        itemName: _nameCtrl.text.trim(),
        unitName: _unitCtrl.text.trim(),
        purchasePrice: _parseNum(_purchasePriceCtrl),
        salesPrice: _parseNum(_salesPriceCtrl),
        lowStockLevel: _parseNum(_lowStockCtrl),
        quantity: _parseNum(_openingQtyCtrl),
      );
    }

    if (!mounted) return;

    if (ok) {
      if (addAnother) {
        setState(() => _savingAnother = false);
        _codeCtrl.clear();
        _nameCtrl.clear();
        _unitCtrl.clear();
        _purchasePriceCtrl.clear();
        _salesPriceCtrl.clear();
        _lowStockCtrl.clear();
        _openingQtyCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Item created. Add another.',
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
      final err = ref.read(inventoryProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(err),
              backgroundColor: AppColors.dangerText),
        );
        ref.read(inventoryProvider.notifier).clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.sidebarBackground,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEdit ? 'Edit Item' : 'Add Item',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon:
                          const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.textSecondary,
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 16),

                // ── Scrollable fields ──────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row: Item Code + Item Name
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _Field(
                                label: 'Item Code',
                                controller: _codeCtrl,
                                enabled: !_busy,
                                hint: 'e.g. ITM-001',
                                autofocus: true,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _Field(
                                label: 'Item Name',
                                controller: _nameCtrl,
                                enabled: !_busy,
                                hint: 'e.g. Laptop Bag',
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Row: Unit + Opening Qty (create only)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _Field(
                                label: 'Unit',
                                controller: _unitCtrl,
                                enabled: !_busy,
                                hint: 'e.g. pcs',
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                              ),
                            ),
                            if (!_isEdit) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: _Field(
                                  label: 'Opening Qty',
                                  controller: _openingQtyCtrl,
                                  enabled: !_busy,
                                  hint: '0',
                                  isNumber: true,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Row: Purchase Price + Sales Price
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _Field(
                                label: 'Purchase Price',
                                controller: _purchasePriceCtrl,
                                enabled: !_busy,
                                hint: '0.00',
                                isNumber: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Field(
                                label: 'Sales Price',
                                controller: _salesPriceCtrl,
                                enabled: !_busy,
                                hint: '0.00',
                                isNumber: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Low Stock Level
                        _Field(
                          label: 'Low Stock Alert',
                          controller: _lowStockCtrl,
                          enabled: !_busy,
                          hint: '0  (alert when qty falls to or below this)',
                          isNumber: true,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // ── Actions ───────────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isEdit) ...[
                      OutlinedButton(
                        onPressed:
                            _busy ? null : () => _save(addAnother: true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                              color: AppColors.primary),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        child: _savingAnother
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary),
                              )
                            : const Text('Create & Add Another'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy
                            ? null
                            : () => _save(addAnother: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : Text(
                                _isEdit ? 'Save' : 'Create',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable field widget
// ─────────────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String hint;
  final bool autofocus;
  final bool isNumber;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.hint,
    this.autofocus = false,
    this.isNumber = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters:
              isNumber ? [_DecimalInputFormatter()] : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 11),
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
          validator: validator,
        ),
      ],
    );
  }
}

class _DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    // allow digits and at most one dot
    final dotCount = text.split('.').length - 1;
    if (dotCount > 1) return oldValue;
    if (RegExp(r'^[0-9]*\.?[0-9]*$').hasMatch(text)) return newValue;
    return oldValue;
  }
}
