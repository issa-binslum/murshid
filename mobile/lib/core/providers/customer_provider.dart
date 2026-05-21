import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_model.dart';
import '../services/customer_service.dart';

class CustomerState {
  final List<Customer> items;
  final bool isLoading;
  final String? error;

  const CustomerState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  CustomerState copyWith({
    List<Customer>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      CustomerState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class CustomerNotifier extends StateNotifier<CustomerState> {
  final CustomerService _svc;

  CustomerNotifier(this._svc) : super(const CustomerState()) {
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
    String? billingAddress,
    String? deliveryAddress,
    double creditLimit = 0,
  }) async {
    try {
      final item = await _svc.create(
        name: name,
        phone: phone,
        email: email,
        billingAddress: billingAddress,
        deliveryAddress: deliveryAddress,
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
    String? billingAddress,
    String? deliveryAddress,
    double? creditLimit,
  }) async {
    try {
      final updated = await _svc.update(
        id,
        name: name,
        phone: phone,
        email: email,
        billingAddress: billingAddress,
        deliveryAddress: deliveryAddress,
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

final customerServiceProvider =
    Provider<CustomerService>((ref) => CustomerService());

final customerProvider =
    StateNotifierProvider<CustomerNotifier, CustomerState>(
  (ref) => CustomerNotifier(ref.watch(customerServiceProvider)),
);
