import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/customer_model.dart';
import '../../core/models/inventory_model.dart';
import '../../core/models/sales_model.dart';
import '../../core/providers/customer_provider.dart';
import '../../core/providers/inventory_provider.dart';
import '../../core/providers/sales_provider.dart';
import '../../core/utils/format.dart';
import 'sales_invoice_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Line entry model
// ─────────────────────────────────────────────────────────────────────────────

class _LineEntry {
  String? itemId;
  double? unitPrice;
  final TextEditingController qty;

  _LineEntry({this.itemId, this.unitPrice, String qtyVal = '1'})
      : qty = TextEditingController(text: qtyVal);

  void dispose() => qty.dispose();

  double get lineTotal =>
      (double.tryParse(qty.text) ?? 0) * (unitPrice ?? 0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class SalesInvoiceFormPage extends ConsumerStatefulWidget {
  final SalesInvoice? editing;
  final SalesOrder? fromOrder;
  final SalesInvoice? fromInvoice;
  const SalesInvoiceFormPage({super.key, this.editing, this.fromOrder, this.fromInvoice});

  @override
  ConsumerState<SalesInvoiceFormPage> createState() =>
      _SalesInvoiceFormPageState();
}

class _SalesInvoiceFormPageState
    extends ConsumerState<SalesInvoiceFormPage> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  String? _customerId;
  final _descCtrl = TextEditingController();
  late List<_LineEntry> _lines;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.editing != null;

  double get _grandTotal =>
      _lines.fold(0, (s, l) => s + l.lineTotal);

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    final fo = widget.fromOrder;
    final fi = widget.fromInvoice;
    _date = e?.date ?? DateTime.now();
    _customerId = e?.customerId ?? fo?.customerId ?? fi?.customerId;
    _descCtrl.text = e?.description ?? fo?.description ?? fi?.description ?? '';
    _lines = e != null && e.items.isNotEmpty
        ? e.items
            .map((i) => _LineEntry(
                  itemId: i.itemId,
                  unitPrice: i.unitPrice,
                  qtyVal: _numStr(i.qty),
                ))
            .toList()
        : fo != null && fo.items.isNotEmpty
            ? fo.items
                .map((i) => _LineEntry(
                      itemId: i.itemId,
                      unitPrice: i.unitPrice,
                      qtyVal: _numStr(i.qty),
                    ))
                .toList()
            : fi != null && fi.items.isNotEmpty
                ? fi.items
                    .map((i) => _LineEntry(
                          itemId: i.itemId,
                          unitPrice: i.unitPrice,
                          qtyVal: _numStr(i.qty),
                        ))
                    .toList()
                : [_LineEntry()];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerProvider.notifier).load();
      ref.read(inventoryProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _addRow() => setState(() => _lines.add(_LineEntry()));

  void _removeRow(int i) {
    if (_lines.length == 1) return;
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  void _onItemSelected(int i, String itemId, List<InventoryItem> inventory) {
    final inv = inventory.firstWhere((item) => item.id == itemId,
        orElse: () => throw StateError('item not found'));
    setState(() {
      _lines[i].itemId = itemId;
      _lines[i].unitPrice = inv.salesPrice;
    });
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

  // ── Validation ─────────────────────────────────────────────────────────────

  bool _validate() {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (_customerId == null) {
      setState(() => _error = 'Please select a customer.');
      return false;
    }
    final valid = _lines.where((l) => l.itemId != null).toList();
    if (valid.isEmpty) {
      setState(() => _error = 'Add at least one item.');
      return false;
    }
    return true;
  }

  List<Map<String, dynamic>> get _linePayload => _lines
      .where((l) => l.itemId != null && l.unitPrice != null)
      .map((l) => {
            'itemId': l.itemId!,
            'qty': double.tryParse(l.qty.text) ?? 1,
            'unitPrice': l.unitPrice!,
          })
      .toList();

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;

    setState(() { _saving = true; _error = null; });

    final ok = await _persist();
    if (!mounted) return;

    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      if (widget.fromOrder != null) {
        final created = ref.read(salesInvoiceProvider).items.first;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SalesInvoiceDetailPage(invoice: created),
          ),
        );
      } else {
        Navigator.of(context).pop(true);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              _isEdit ? 'Invoice updated.' : 'Invoice created.',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
          backgroundColor: AppColors.successText,
          behavior: SnackBarBehavior.floating,
          width: 320,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else {
      _handleError();
    }
  }

  Future<void> _submitAndAddAnother() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;

    setState(() { _saving = true; _error = null; });

    final ok = await _persist();
    if (!mounted) return;

    if (ok) {
      for (final l in _lines) { l.dispose(); }
      setState(() {
        _lines = [_LineEntry()];
        _customerId = null;
        _descCtrl.clear();
        _date = DateTime.now();
        _saving = false;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invoice created. Ready for next entry.',
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
      _handleError();
    }
  }

  Future<bool> _persist() async {
    if (_isEdit) {
      return ref.read(salesInvoiceProvider.notifier).update(
            widget.editing!.id,
            customerId: _customerId,
            date: _date,
            items: _linePayload,
            description: _descCtrl.text.trim(),
          );
    } else {
      return ref.read(salesInvoiceProvider.notifier).create(
            customerId: _customerId!,
            date: _date,
            items: _linePayload,
            description: _descCtrl.text.trim(),
          );
    }
  }

  void _handleError() {
    final err = ref.read(salesInvoiceProvider).error ?? 'An error occurred.';
    ref.read(salesInvoiceProvider.notifier).clearError();
    setState(() { _saving = false; _error = err; });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerProvider).items;
    final inventory = ref.watch(inventoryProvider).items;
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: isWide
          ? _wideLayout(customers, inventory)
          : _narrowLayout(customers, inventory),
    );
  }

  Widget _wideLayout(List<Customer> customers, List<InventoryItem> inventory) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: _cardBody(customers, inventory),
        ),
      ),
    );
  }

  Widget _narrowLayout(
      List<Customer> customers, List<InventoryItem> inventory) {
    return Column(
      children: [
        _Header(
          title: _isEdit ? 'Edit Sales Invoice' : 'New Sales Invoice',
          onClose: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: _formContent(customers, inventory),
          ),
        ),
        _Footer(
          saving: _saving,
          isEdit: _isEdit,
          onSave: _submit,
          onSaveAndAdd: _isEdit ? null : _submitAndAddAnother,
        ),
      ],
    );
  }

  Widget _cardBody(
      List<Customer> customers, List<InventoryItem> inventory) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Header(
          title: _isEdit ? 'Edit Sales Invoice' : 'New Sales Invoice',
          onClose: () => Navigator.of(context).pop(),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
            child: _formContent(customers, inventory),
          ),
        ),
        _Footer(
          saving: _saving,
          isEdit: _isEdit,
          onSave: _submit,
          onSaveAndAdd: _isEdit ? null : _submitAndAddAnother,
        ),
      ],
    );
  }

  // ── Form content ───────────────────────────────────────────────────────────

  Widget _formContent(
      List<Customer> customers, List<InventoryItem> inventory) {
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

          // ── Customer ─────────────────────────────────────────────────────
          _SectionLabel('Customer'),
          const SizedBox(height: 14),
          _FieldLabel('Customer'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _customerId,
            decoration: _dec(hint: 'Select customer'),
            isExpanded: true,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textPrimary),
            items: customers
                .map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _customerId = v),
          ),

          const SizedBox(height: 24),

          // ── Invoice details ───────────────────────────────────────────────
          _SectionLabel('Invoice Details'),
          const SizedBox(height: 14),

          if (isWide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _datePicker()),
              const SizedBox(width: 14),
              Expanded(child: _descriptionField()),
            ])
          else
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _datePicker(),
                  const SizedBox(height: 14),
                  _descriptionField(),
                ]),

          const SizedBox(height: 24),

          // ── Items inline table ────────────────────────────────────────────
          _SectionLabel('Items'),
          const SizedBox(height: 14),
          _ItemsTable(
            lines: _lines,
            inventory: inventory,
            onAddRow: _addRow,
            onRemoveRow: _removeRow,
            onItemSelected: (i, itemId) =>
                _onItemSelected(i, itemId, inventory),
            onItemCleared: (i) => setState(() {
              _lines[i].itemId = null;
              _lines[i].unitPrice = null;
            }),
            onQtyChanged: () => setState(() {}),
          ),

          const SizedBox(height: 16),

          // ── Grand total ───────────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.pageBackground,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('Grand Total',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const Spacer(),
                Text(
                  fmtMoney(_grandTotal),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ],
            ),
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
                        fontSize: 13, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _descriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Description (optional)'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descCtrl,
          maxLines: 2,
          style: const TextStyle(
              fontSize: 13, color: AppColors.textPrimary),
          decoration: _dec(hint: 'Optional notes about this invoice'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline items table  (identical structure to the order form's _ItemsTable)
// ─────────────────────────────────────────────────────────────────────────────

class _ItemsTable extends StatefulWidget {
  final List<_LineEntry> lines;
  final List<InventoryItem> inventory;
  final VoidCallback onAddRow;
  final void Function(int) onRemoveRow;
  final void Function(int, String) onItemSelected;
  final void Function(int) onItemCleared;
  final VoidCallback onQtyChanged;

  const _ItemsTable({
    required this.lines,
    required this.inventory,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onItemSelected,
    required this.onItemCleared,
    required this.onQtyChanged,
  });

  @override
  State<_ItemsTable> createState() => _ItemsTableState();
}

class _ItemsTableState extends State<_ItemsTable> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _tableHeader(),
          ...List.generate(widget.lines.length, (i) {
            return _TableRow(
              key: ValueKey(i),
              index: i,
              entry: widget.lines[i],
              inventory: widget.inventory,
              canRemove: widget.lines.length > 1,
              onRemove: () => widget.onRemoveRow(i),
              onItemSelected: (id) => widget.onItemSelected(i, id),
              onItemCleared: () => widget.onItemCleared(i),
              onQtyChanged: () {
                setState(() {});
                widget.onQtyChanged();
              },
            );
          }),
          // Add row footer
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: widget.onAddRow,
                  icon: const Icon(Icons.add_rounded,
                      size: 15, color: AppColors.primary),
                  label: const Text('Add row',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 5, child: _TH('Item')),
          SizedBox(width: 8),
          Expanded(flex: 2, child: _TH('Qty')),
          SizedBox(width: 8),
          Expanded(flex: 3, child: _TH('Unit Price')),
          SizedBox(width: 8),
          Expanded(flex: 3, child: _TH('Line Total', right: true)),
          SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  final bool right;
  const _TH(this.text, {this.right = false});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Single table row
// ─────────────────────────────────────────────────────────────────────────────

class _TableRow extends StatefulWidget {
  final int index;
  final _LineEntry entry;
  final List<InventoryItem> inventory;
  final bool canRemove;
  final VoidCallback onRemove;
  final ValueChanged<String> onItemSelected;
  final VoidCallback onItemCleared;
  final VoidCallback onQtyChanged;

  const _TableRow({
    super.key,
    required this.index,
    required this.entry,
    required this.inventory,
    required this.canRemove,
    required this.onRemove,
    required this.onItemSelected,
    required this.onItemCleared,
    required this.onQtyChanged,
  });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final lineTotal = entry.lineTotal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Item dropdown
          Expanded(
            flex: 5,
            child: DropdownButtonFormField<String>(
              value: entry.itemId,
              isExpanded: true,
              isDense: true,
              decoration: _cellDec('Select item'),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textPrimary),
              items: widget.inventory
                  .map((item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(
                          '${item.itemName} (${item.unitName})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  widget.onItemSelected(v);
                } else {
                  widget.onItemCleared();
                }
              },
              validator: (v) => v == null ? 'Required' : null,
            ),
          ),
          const SizedBox(width: 8),

          // Qty field
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: entry.qty,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d*'))
              ],
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textPrimary),
              decoration: _cellDec('1'),
              onChanged: (_) {
                setState(() {});
                widget.onQtyChanged();
              },
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Invalid';
                return null;
              },
            ),
          ),
          const SizedBox(width: 8),

          // Unit price (locked)
          Expanded(
            flex: 3,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.unitPrice != null
                          ? fmtMoney(entry.unitPrice!)
                          : '—',
                      style: TextStyle(
                        fontSize: 12,
                        color: entry.unitPrice != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.lock_outline_rounded,
                      size: 12, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Line total
          Expanded(
            flex: 3,
            child: Text(
              fmtMoney(lineTotal),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: lineTotal > 0
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ),

          // Remove button
          SizedBox(
            width: 36,
            child: widget.canRemove
                ? IconButton(
                    onPressed: widget.onRemove,
                    icon: const Icon(
                        Icons.remove_circle_outline_rounded,
                        size: 16,
                        color: AppColors.dangerText),
                    tooltip: 'Remove row',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
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
            tooltip: 'Close',
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
  final bool isEdit;
  final VoidCallback onSave;
  final VoidCallback? onSaveAndAdd;

  const _Footer({
    required this.saving,
    required this.isEdit,
    required this.onSave,
    this.onSaveAndAdd,
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6)),
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      ),
      child: saving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Text(
              isEdit ? 'Save Changes' : 'Create Invoice',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
    );

    final addAnotherBtn = onSaveAndAdd != null
        ? OutlinedButton(
            onPressed: saving ? null : onSaveAndAdd,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
            ),
            child: const Text('Create & Add Another',
                style: TextStyle(fontWeight: FontWeight.w600)),
          )
        : null;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                  'Totals update as you fill in items.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                const Spacer(),
                if (addAnotherBtn != null) ...[
                  addAnotherBtn,
                  const SizedBox(width: 10),
                ],
                saveBtn,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                saveBtn,
                if (addAnotherBtn != null) ...[
                  const SizedBox(height: 8),
                  addAnotherBtn,
                ],
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
        ],
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
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.dangerBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.dangerText.withAlpha(80)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 16, color: AppColors.dangerText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.dangerText)),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Input decorations
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _dec({required String hint}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          fontSize: 13, color: AppColors.textSecondary),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      isDense: true,
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
          borderSide: const BorderSide(
              color: AppColors.dangerText, width: 1.5)),
      filled: true,
      fillColor: Colors.white,
    );

InputDecoration _cellDec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          fontSize: 12, color: AppColors.textSecondary),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      isDense: true,
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
          borderSide: const BorderSide(
              color: AppColors.dangerText, width: 1.5)),
      filled: true,
      fillColor: Colors.white,
      errorStyle: const TextStyle(fontSize: 10, height: 0.8),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Utility
// ─────────────────────────────────────────────────────────────────────────────

String _numStr(double v) =>
    v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);