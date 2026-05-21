import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sales_model.dart';
import '../services/sales_service.dart';

// ── Orders ────────────────────────────────────────────────────────────────────

class SalesOrderState {
  final List<SalesOrder> items;
  final bool isLoading;
  final String? error;

  const SalesOrderState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  SalesOrderState copyWith({
    List<SalesOrder>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      SalesOrderState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class SalesOrderNotifier extends StateNotifier<SalesOrderState> {
  final SalesOrderService _svc;
  SalesOrderNotifier(this._svc) : super(const SalesOrderState()) {
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
    required String customerId,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    String? address,
    String? description,
  }) async {
    try {
      final item = await _svc.create(
        customerId: customerId,
        date: date,
        items: items,
        address: address,
        description: description,
      );
      state = state.copyWith(items: [item, ...state.items]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> update(
    String id, {
    String? customerId,
    DateTime? date,
    List<Map<String, dynamic>>? items,
    String? address,
    String? description,
  }) async {
    try {
      final updated = await _svc.update(
        id,
        customerId: customerId,
        date: date,
        items: items,
        address: address,
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

  Future<bool> cancel(String id) async {
    try {
      await _svc.cancel(id);
      state = state.copyWith(
        items: state.items.where((i) => i.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Invoices ──────────────────────────────────────────────────────────────────

class SalesInvoiceState {
  final List<SalesInvoice> items;
  final bool isLoading;
  final String? error;

  const SalesInvoiceState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  SalesInvoiceState copyWith({
    List<SalesInvoice>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      SalesInvoiceState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class SalesInvoiceNotifier extends StateNotifier<SalesInvoiceState> {
  final SalesInvoiceService _svc;
  SalesInvoiceNotifier(this._svc) : super(const SalesInvoiceState()) {
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
    required String customerId,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    String? description,
  }) async {
    try {
      final item = await _svc.create(
        customerId: customerId,
        date: date,
        items: items,
        description: description,
      );
      state = state.copyWith(items: [item, ...state.items]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> update(
    String id, {
    String? customerId,
    DateTime? date,
    List<Map<String, dynamic>>? items,
    String? description,
  }) async {
    try {
      final updated = await _svc.update(
        id,
        customerId: customerId,
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
        items: state.items.where((i) => i.id != id).toList(),
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

final salesOrderServiceProvider =
    Provider<SalesOrderService>((ref) => SalesOrderService());

final salesOrderProvider =
    StateNotifierProvider<SalesOrderNotifier, SalesOrderState>(
  (ref) => SalesOrderNotifier(ref.watch(salesOrderServiceProvider)),
);

final salesInvoiceServiceProvider =
    Provider<SalesInvoiceService>((ref) => SalesInvoiceService());

final salesInvoiceProvider =
    StateNotifierProvider<SalesInvoiceNotifier, SalesInvoiceState>(
  (ref) => SalesInvoiceNotifier(ref.watch(salesInvoiceServiceProvider)),
);
