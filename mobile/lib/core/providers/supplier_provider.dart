import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier_model.dart';
import '../services/supplier_service.dart';

class SupplierState {
  final List<Supplier> items;
  final bool isLoading;
  final String? error;

  const SupplierState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  SupplierState copyWith({
    List<Supplier>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      SupplierState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class SupplierNotifier extends StateNotifier<SupplierState> {
  final SupplierService _svc;

  SupplierNotifier(this._svc) : super(const SupplierState()) {
    Future.microtask(load);
  }

  Future<void> load({String? q}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _svc.fetchAll(q: q);
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> create({
    required String name,
    String? phone,
    String? email,
    String? address,
    double creditLimit = 0,
  }) async {
    try {
      final item = await _svc.create(
        name: name,
        phone: phone,
        email: email,
        address: address,
        creditLimit: creditLimit,
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
    String? name,
    String? phone,
    String? email,
    String? address,
    double? creditLimit,
  }) async {
    try {
      final updated = await _svc.update(
        id,
        name: name,
        phone: phone,
        email: email,
        address: address,
        creditLimit: creditLimit,
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

  Future<bool> delete(String id) async {
    try {
      await _svc.delete(id);
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

final supplierServiceProvider =
    Provider<SupplierService>((ref) => SupplierService());

final supplierProvider =
    StateNotifierProvider<SupplierNotifier, SupplierState>(
  (ref) => SupplierNotifier(ref.watch(supplierServiceProvider)),
);
