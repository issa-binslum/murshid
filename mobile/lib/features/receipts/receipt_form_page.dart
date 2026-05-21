import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/account_model.dart';
import '../../core/models/customer_model.dart';
import '../../core/models/inventory_model.dart';
import '../../core/models/receipt_model.dart';
import '../../core/models/sales_model.dart';
import '../../core/providers/account_provider.dart';
import '../../core/providers/customer_provider.dart';
import '../../core/providers/inventory_provider.dart';
import '../../core/providers/receipt_provider.dart';
import '../../core/providers/sales_provider.dart';
import '../../core/utils/format.dart';

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

  double get lineTotal => (double.tryParse(qty.text) ?? 0) * (unitPrice ?? 0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class ReceiptFormPage extends ConsumerStatefulWidget {
  final Receipt? editing;
  final SalesInvoice? fromInvoice;
  const ReceiptFormPage({super.key, this.editing, this.fromInvoice});

  @override
  ConsumerState<ReceiptFormPage> createState() => _ReceiptFormPageState();
}

class _ReceiptFormPageState extends ConsumerState<ReceiptFormPage> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  // create mode
  String? _customerId;
  // shared
  final _paidByCtrl = TextEditingController();
  late List<_LineEntry> _lines;
  String? _accountId;
  final _descCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.editing != null;
  double get _grandTotal => _lines.fold(0.0, (s, l) => s + l.lineTotal);

  List<Map<String, dynamic>> _itemsPayload() => _lines
      .where((l) => l.itemId != null && (double.tryParse(l.qty.text) ?? 0) > 0)
      .map((l) => {
            'itemId': l.itemId!,
            'qty': double.parse(l.qty.text),
            'unitPrice': l.unitPrice ?? 0.0,
          })
      .toList();
  // In edit mode, if no items have been filled, keep the original stored amount.
  double get _effectiveAmount =>
      (_isEdit && _grandTotal <= 0) ? (widget.editing!.amount) : _grandTotal;
  bool get _hasNewItems => _lines.any((l) => l.itemId != null);

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    final fi = widget.fromInvoice;
    _date = e?.date ?? DateTime.now();
    _accountId = e?.accountId;
    _descCtrl.text = e?.description ?? fi?.description ?? '';
    if (_isEdit) {
      _paidByCtrl.text = e!.paidBy ?? '';
      // Pre-fill lines from stored receipt items
      if (e.items.isNotEmpty) {
        _lines = e.items.map((ri) {
          final entry = _LineEntry();
          entry.itemId = ri.itemId;
          entry.unitPrice = ri.unitPrice;
          entry.qty.text = ri.qty.truncateToDouble() == ri.qty
              ? ri.qty.toInt().toString()
              : ri.qty.toString();
          return entry;
        }).toList();
      } else {
        _lines = [_LineEntry()];
      }
    } else if (fi != null && fi.items.isNotEmpty) {
      _customerId = fi.customerId;
      _lines = fi.items.map((i) {
        final qtyStr = i.qty.truncateToDouble() == i.qty
            ? i.qty.toInt().toString()
            : i.qty.toString();
        return _LineEntry(itemId: i.itemId, unitPrice: i.unitPrice, qtyVal: qtyStr);
      }).toList();
    } else {
      if (fi != null) _customerId = fi.customerId;
      _lines = [_LineEntry()];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accountProvider.notifier).load();
      ref.read(customerProvider.notifier).load();
      ref.read(inventoryProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _paidByCtrl.dispose();
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  bool _validateCreate() {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (_customerId == null) {
      setState(() => _error = 'Please select who paid.');
      return false;
    }
    if (_accountId == null) {
      setState(() => _error = 'Please select the receiving account.');
      return false;
    }
    if (_lines.every((l) => l.itemId == null)) {
      setState(() => _error = 'Add at least one item.');
      return false;
    }
    if (_grandTotal <= 0) {
      setState(() => _error = 'Total amount must be greater than zero.');
      return false;
    }
    return true;
  }

  bool _validateEdit() {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (_accountId == null) {
      setState(() => _error = 'Please select the receiving account.');
      return false;
    }
    // Items are optional in edit mode — original amount is kept when none selected.
    if (_hasNewItems && _grandTotal <= 0) {
      setState(() => _error = 'Total amount must be greater than zero.');
      return false;
    }
    return true;
  }

  Future<void> _submit(List<Customer> customers) async {
    FocusScope.of(context).unfocus();
    if (!_validateCreate()) return;

    setState(() { _saving = true; _error = null; });

    final customer = customers.firstWhere((c) => c.id == _customerId);
    final ok = await ref.read(receiptProvider.notifier).create(
          date: _date,
          accountId: _accountId!,
          amount: _grandTotal,
          paidBy: customer.name,
          customerId: _customerId,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          items: _itemsPayload(),
        );

    if (!mounted) return;
    if (ok) {
      // Refresh sales invoices so status changes are visible immediately
      ref.read(salesInvoiceProvider.notifier).load();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(_snack('Receipt recorded.'));
    } else {
      _handleError();
    }
  }

  Future<void> _submitEdit() async {
    FocusScope.of(context).unfocus();
    if (!_validateEdit()) return;

    setState(() { _saving = true; _error = null; });

    final ok = await ref.read(receiptProvider.notifier).update(
          widget.editing!.id,
          date: _date,
          paidBy: _paidByCtrl.text.trim(),
          accountId: _accountId,
          amount: _effectiveAmount,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          items: _itemsPayload(),
        );

    if (!mounted) return;
    if (ok) {
      ref.read(salesInvoiceProvider.notifier).load();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(_snack('Receipt updated.'));
    } else {
      _handleError();
    }
  }

  void _handleError() {
    final err = ref.read(receiptProvider).error ?? 'An error occurred.';
    ref.read(receiptProvider.notifier).clearError();
    setState(() { _saving = false; _error = err; });
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

  Future<void> _submitAndAddAnother(List<Customer> customers) async {
    FocusScope.of(context).unfocus();
    if (!_validateCreate()) return;

    setState(() { _saving = true; _error = null; });

    final customer = customers.firstWhere((c) => c.id == _customerId);
    final ok = await ref.read(receiptProvider.notifier).create(
          date: _date,
          accountId: _accountId!,
          amount: _grandTotal,
          paidBy: customer.name,
          customerId: _customerId,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          items: _itemsPayload(),
        );

    if (!mounted) return;

    if (ok) {
      // Refresh sales invoices so status changes are visible immediately
      ref.read(salesInvoiceProvider.notifier).load();
      for (final l in _lines) { l.dispose(); }
      setState(() {
        _lines = [_LineEntry()];
        _customerId = null;
        _descCtrl.clear();
        _date = DateTime.now();
        _saving = false;
        _error = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(_snack('Receipt recorded. Ready for next entry.'));
    } else {
      _handleError();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerProvider).items;
    final accounts = ref.watch(accountProvider).items;
    final inventory = ref.watch(inventoryProvider).items;
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: isWide
          ? _wideLayout(customers, accounts, inventory)
          : _narrowLayout(customers, accounts, inventory),
    );
  }

  Widget _wideLayout(List<Customer> customers, List<AccountItem> accounts,
      List<InventoryItem> inventory) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: _cardBody(customers, accounts, inventory),
        ),
      ),
    );
  }

  Widget _narrowLayout(List<Customer> customers, List<AccountItem> accounts,
      List<InventoryItem> inventory) {
    return Column(
      children: [
        _Header(
          title: _isEdit ? 'Edit Receipt' : 'New Receipt',
          onClose: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: _formContent(customers, accounts, inventory),
          ),
        ),
        _Footer(
          saving: _saving,
          isEdit: _isEdit,
          onSave: _isEdit ? _submitEdit : () => _submit(customers),
          onSaveAndAdd: _isEdit ? null : () => _submitAndAddAnother(customers),
        ),
      ],
    );
  }

  Widget _cardBody(List<Customer> customers, List<AccountItem> accounts,
      List<InventoryItem> inventory) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Header(
          title: _isEdit ? 'Edit Receipt' : 'New Receipt',
          onClose: () => Navigator.of(context).pop(),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
            child: _formContent(customers, accounts, inventory),
          ),
        ),
        _Footer(
          saving: _saving,
          isEdit: _isEdit,
          onSave: _isEdit ? _submitEdit : () => _submit(customers),
          onSaveAndAdd: _isEdit ? null : () => _submitAndAddAnother(customers),
        ),
      ],
    );
  }

  // ── Form content ───────────────────────────────────────────────────────────

  Widget _formContent(List<Customer> customers, List<AccountItem> accounts,
      List<InventoryItem> inventory) {
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

          // ── Receipt Info ─────────────────────────────────────────────────
          _SectionLabel('Receipt Info'),
          const SizedBox(height: 14),

          if (isWide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _datePicker()),
              const SizedBox(width: 14),
              Expanded(
                child: _isEdit
                    ? _paidByTextField()
                    : _paidByDropdown(customers),
              ),
            ])
          else
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _datePicker(),
              const SizedBox(height: 14),
              _isEdit ? _paidByTextField() : _paidByDropdown(customers),
            ]),

          const SizedBox(height: 14),
          _FieldLabel('Received In'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _accountId,
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
          _FieldLabel('Description (optional)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descCtrl,
            maxLines: 2,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textPrimary),
            decoration: _dec(hint: 'Notes about this receipt…'),
          ),

          const SizedBox(height: 28),

          // ── Items ───────────────────────────────────────────────────────────
          _SectionLabel('Items'),
          const SizedBox(height: 14),
            _ItemsTable(
              lines: _lines,
              inventory: inventory,
              inventoryLoading: ref.watch(inventoryProvider).isLoading,
              onAddRow: _addRow,
              onRemoveRow: _removeRow,
              onQtyChanged: () => setState(() {}),
            ),

            const SizedBox(height: 16),

            // ── Grand total ────────────────────────────────────────────────
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Grand Total',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      if (_isEdit && !_hasNewItems)
                        const Text('Using original amount',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    fmtMoney(_effectiveAmount),
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
                        fontSize: 13,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paidByDropdown(List<Customer> customers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Paid By'),
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
          validator: (v) =>
              v == null ? 'Select who paid' : null,
        ),
      ],
    );
  }

  Widget _paidByTextField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Paid By'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _paidByCtrl,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          decoration: _dec(hint: 'e.g. John Doe'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter who paid' : null,
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
// Inline items table (horizontally scrollable for narrow screens)
// ─────────────────────────────────────────────────────────────────────────────

class _ItemsTable extends StatefulWidget {
  final List<_LineEntry> lines;
  final List<InventoryItem> inventory;
  final bool inventoryLoading;
  final VoidCallback onAddRow;
  final void Function(int) onRemoveRow;
  final VoidCallback onQtyChanged;

  const _ItemsTable({
    required this.lines,
    required this.inventory,
    required this.inventoryLoading,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onQtyChanged,
  });

  @override
  State<_ItemsTable> createState() => _ItemsTableState();
}

class _ItemsTableState extends State<_ItemsTable> {
  static const double _minWidth = 520.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.inventoryLoading && widget.inventory.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textSecondary),
                    ),
                    SizedBox(width: 10),
                    Text('Loading items…',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          : LayoutBuilder(
              builder: (ctx, constraints) {
                final tableWidth = constraints.maxWidth > _minWidth
                    ? constraints.maxWidth
                    : _minWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        _tableHeader(),
                        ...List.generate(
                            widget.lines.length,
                            (i) => _TableRow(
                                  key: ValueKey(i),
                                  index: i,
                                  entry: widget.lines[i],
                                  inventory: widget.inventory,
                                  canRemove: widget.lines.length > 1,
                                  onRemove: () => widget.onRemoveRow(i),
                                  onQtyChanged: () {
                                    setState(() {});
                                    widget.onQtyChanged();
                                  },
                                )),
                        // ── Add row footer ────────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            border: Border(
                                top: BorderSide(color: AppColors.border)),
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
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 28, child: _TH('#')),
          SizedBox(width: 8),
          Expanded(flex: 6, child: _TH('Item')),
          SizedBox(width: 8),
          SizedBox(width: 60, child: _TH('Qty')),
          SizedBox(width: 8),
          SizedBox(width: 100, child: _TH('Unit Price')),
          SizedBox(width: 8),
          SizedBox(width: 100, child: _TH('Total', right: true)),
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
  final VoidCallback onQtyChanged;

  const _TableRow({
    super.key,
    required this.index,
    required this.entry,
    required this.inventory,
    required this.canRemove,
    required this.onRemove,
    required this.onQtyChanged,
  });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  String? _selectedItemId;
  double? _unitPrice;

  @override
  void initState() {
    super.initState();
    _selectedItemId = widget.entry.itemId;
    _unitPrice = widget.entry.unitPrice;
  }

  @override
  void didUpdateWidget(_TableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync local state when the entry object itself swapped (e.g. row
    // removal shifted indices). Do NOT sync on ordinary parent rebuilds —
    // that would clobber the selection the user just made.
    if (!identical(oldWidget.entry, widget.entry)) {
      _selectedItemId = widget.entry.itemId;
      _unitPrice = widget.entry.unitPrice;
    }
  }

  double get _lineTotal =>
      (double.tryParse(widget.entry.qty.text) ?? 0) * (_unitPrice ?? 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // # index
          SizedBox(
            width: 28,
            child: Text(
              '${widget.index + 1}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),

          // Item dropdown
          Expanded(
            flex: 5,
            child: DropdownButtonFormField<String>(
              value: _selectedItemId,
              isExpanded: true,
              isDense: true,
              decoration: _cellDec('Select item'),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textPrimary),
              items: widget.inventory
                  .map((item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(
                          item.itemName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  final inv = widget.inventory
                      .firstWhere((it) => it.id == v);
                  setState(() {
                    _selectedItemId = v;
                    _unitPrice = inv.salesPrice;
                    widget.entry.itemId = v;
                    widget.entry.unitPrice = inv.salesPrice;
                  });
                } else {
                  setState(() {
                    _selectedItemId = null;
                    _unitPrice = null;
                    widget.entry.itemId = null;
                    widget.entry.unitPrice = null;
                  });
                }
                widget.onQtyChanged();
              },
              validator: (v) => v == null ? 'Required' : null,
            ),
          ),
          const SizedBox(width: 8),

          // Qty field
          SizedBox(
            width: 60,
            child: TextFormField(
              controller: widget.entry.qty,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d*')),
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

          // Unit price (read-only, auto-filled)
          SizedBox(
            width: 100,
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
                      _unitPrice != null ? fmtMoney(_unitPrice!) : '—',
                      style: TextStyle(
                        fontSize: 12,
                        color: _unitPrice != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.lock_outline_rounded,
                      size: 11, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Line total
          SizedBox(
            width: 100,
            child: Text(
              fmtMoney(_lineTotal),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _lineTotal > 0
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
    final saveLabel = isEdit ? 'Save Changes' : 'Record Receipt';
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
          : Text(saveLabel,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: isEdit
          ? SizedBox(width: double.infinity, child: saveBtn)
          : (isWide
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
                ])),
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

InputDecoration _cellDec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          fontSize: 11, color: AppColors.textSecondary),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      isDense: true,
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
