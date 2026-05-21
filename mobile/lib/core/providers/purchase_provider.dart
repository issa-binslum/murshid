import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/purchase_model.dart';
import '../services/purchase_service.dart';

// ── Purchase Orders ───────────────────────────────────────────────────────────

class PurchaseOrderState {
  final List<PurchaseOrder> items;
  final bool isLoading;
  final String? error;

  const PurchaseOrderState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  PurchaseOrderState copyWith({
    List<PurchaseOrder>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      PurchaseOrderState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class PurchaseOrderNotifier extends StateNotifier<PurchaseOrderState> {
  final PurchaseOrderService _svc;

  PurchaseOrderNotifier(this._svc) : super(const PurchaseOrderState()) {
    Future.microtask(load);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _svc.fetchAll();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> create({
    required String supplierId,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    String? description,
  }) async {
    try {
      final created = await _svc.create(
        supplierId: supplierId,
        date: date,
        items: items,
        description: description,
      );
      state = state.copyWith(items: [created, ...state.items]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> update(
    String id, {
    String? supplierId,
    DateTime? date,
    List<Map<String, dynamic>>? items,
    String? description,
  }) async {
    try {
      final updated = await _svc.update(
        id,
        supplierId: supplierId,
        date: date,
        items: items,
        description: description,
      );
      state = state.copyWith(
        items: state.items.map((o) => o.id == id ? updated : o).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> cancel(String id) async {
    try {
      await _svc.cancel(id);
      state = state.copyWith(
        items: state.items
            .map((o) => o.id == id
                ? PurchaseOrder(
                    id: o.id,
                    supplierId: o.supplierId,
                    supplierName: o.supplierName,
                    date: o.date,
                    description: o.description,
                    total: o.total,
                    isCancelled: true,
                    items: o.items,
                  )
                : o)
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Purchase Invoices ─────────────────────────────────────────────────────────

class PurchaseInvoiceState {
  final List<PurchaseInvoice> items;
  final bool isLoading;
  final String? error;

  const PurchaseInvoiceState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  PurchaseInvoiceState copyWith({
    List<PurchaseInvoice>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      PurchaseInvoiceState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class PurchaseInvoiceNotifier extends StateNotifier<PurchaseInvoiceState> {
  final PurchaseInvoiceService _svc;

  PurchaseInvoiceNotifier(this._svc) : super(const PurchaseInvoiceState()) {
    Future.microtask(load);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _svc.fetchAll();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> create({
    required String supplierId,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    String? description,
  }) async {
    try {
      final created = await _svc.create(
        supplierId: supplierId,
        date: date,
        items: items,
        description: description,
      );
      state = state.copyWith(items: [created, ...state.items]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> update(
    String id, {
    String? supplierId,
    DateTime? date,
    List<Map<String, dynamic>>? items,
    String? description,
  }) async {
    try {
      final updated = await _svc.update(
        id,
        supplierId: supplierId,
        date: date,
        items: items,
        description: description,
      );
      state = state.copyWith(
        items: state.items.map((i) => i.id == id ? updated : i).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> markPaid(String id) async {
    try {
      final updated = await _svc.markPaid(id);
      state = state.copyWith(
        items: state.items.map((i) => i.id == id ? updated : i).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> cancel(String id) async {
    try {
      await _svc.cancel(id);
      state = state.copyWith(
        items: state.items
            .map((inv) => inv.id == id
                ? PurchaseInvoice(
                    id: inv.id,
                    supplierId: inv.supplierId,
                    supplierName: inv.supplierName,
                    date: inv.date,
                    description: inv.description,
                    total: inv.total,
                    status: 'CANCELLED',
                    paidAmount: inv.paidAmount,
                    items: inv.items,
                  )
                : inv)
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Providers ─────────────────────────────────────────────────────────────────

final purchaseOrderServiceProvider =
    Provider<PurchaseOrderService>((ref) => PurchaseOrderService());

final purchaseOrderProvider =
    StateNotifierProvider<PurchaseOrderNotifier, PurchaseOrderState>(
  (ref) => PurchaseOrderNotifier(ref.watch(purchaseOrderServiceProvider)),
);

final purchaseInvoiceServiceProvider =
    Provider<PurchaseInvoiceService>((ref) => PurchaseInvoiceService());

final purchaseInvoiceProvider =
    StateNotifierProvider<PurchaseInvoiceNotifier, PurchaseInvoiceState>(
  (ref) => PurchaseInvoiceNotifier(ref.watch(purchaseInvoiceServiceProvider)),
);
