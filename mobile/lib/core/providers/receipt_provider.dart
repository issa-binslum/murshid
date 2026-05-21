import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/receipt_model.dart';
import '../services/receipt_service.dart';

class ReceiptState {
  final List<Receipt> items;
  final bool isLoading;
  final String? error;

  const ReceiptState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  ReceiptState copyWith({
    List<Receipt>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      ReceiptState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class ReceiptNotifier extends StateNotifier<ReceiptState> {
  final ReceiptService _svc;

  ReceiptNotifier(this._svc) : super(const ReceiptState()) {
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
    String? paidBy,
    String? customerId,
    String? description,
    List<Map<String, dynamic>> items = const [],
  }) async {
    try {
      final item = await _svc.create(
        date: date,
        accountId: accountId,
        amount: amount,
        paidBy: paidBy,
        customerId: customerId,
        description: description,
        items: items,
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
    DateTime? date,
    String? paidBy,
    String? accountId,
    double? amount,
    String? description,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final updated = await _svc.update(
        id,
        date: date,
        paidBy: paidBy,
        accountId: accountId,
        amount: amount,
        description: description,
        items: items,
      );
      state = state.copyWith(
        items: state.items.map((r) => r.id == id ? updated : r).toList(),
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
        items: state.items.where((r) => r.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final receiptServiceProvider =
    Provider<ReceiptService>((ref) => ReceiptService());

final receiptProvider =
    StateNotifierProvider<ReceiptNotifier, ReceiptState>(
  (ref) => ReceiptNotifier(ref.watch(receiptServiceProvider)),
);
