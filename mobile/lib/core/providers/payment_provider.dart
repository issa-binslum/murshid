import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';

class PaymentState {
  final List<Payment> items;
  final bool isLoading;
  final String? error;

  const PaymentState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  PaymentState copyWith({
    List<Payment>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      PaymentState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  final PaymentService _svc;

  PaymentNotifier(this._svc) : super(const PaymentState()) {
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
    required DateTime date,
    required String accountId,
    required double amount,
    String? payee,
    String? supplierId,
    String? description,
  }) async {
    try {
      final item = await _svc.create(
        date: date,
        accountId: accountId,
        amount: amount,
        payee: payee,
        supplierId: supplierId,
        description: description,
      );
      state = state.copyWith(items: [item, ...state.items]);
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
        items: state.items.where((p) => p.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final paymentServiceProvider =
    Provider<PaymentService>((ref) => PaymentService());

final paymentProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>(
  (ref) => PaymentNotifier(ref.watch(paymentServiceProvider)),
);
