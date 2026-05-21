import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory_model.dart';
import '../services/inventory_service.dart';

class InventoryState {
  final List<InventoryItem> items;
  final bool isLoading;
  final String? error;

  const InventoryState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  InventoryState copyWith({
    List<InventoryItem>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      InventoryState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class InventoryNotifier extends StateNotifier<InventoryState> {
  final InventoryService _svc;

  InventoryNotifier(this._svc) : super(const InventoryState()) {
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
    required String itemCode,
    required String itemName,
    required String unitName,
    double purchasePrice = 0,
    double salesPrice = 0,
    double lowStockLevel = 0,
    double quantity = 0,
    String? description,
  }) async {
    try {
      final item = await _svc.create(
        itemCode: itemCode,
        itemName: itemName,
        unitName: unitName,
        purchasePrice: purchasePrice,
        salesPrice: salesPrice,
        lowStockLevel: lowStockLevel,
        quantity: quantity,
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
    String? itemCode,
    String? itemName,
    String? unitName,
    double? purchasePrice,
    double? salesPrice,
    double? lowStockLevel,
    String? description,
  }) async {
    try {
      final updated = await _svc.update(
        id,
        itemCode: itemCode,
        itemName: itemName,
        unitName: unitName,
        purchasePrice: purchasePrice,
        salesPrice: salesPrice,
        lowStockLevel: lowStockLevel,
        description: description,
      );
      state = state.copyWith(
        items:
            state.items.map((i) => i.id == id ? updated : i).toList(),
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

final inventoryServiceProvider =
    Provider<InventoryService>((ref) => InventoryService());

final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>(
  (ref) => InventoryNotifier(ref.watch(inventoryServiceProvider)),
);
