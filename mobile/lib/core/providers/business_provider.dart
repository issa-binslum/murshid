import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business_detail_model.dart';
import '../services/business_service.dart';

class BusinessState {
  final List<BusinessDetail> items;
  final bool isLoading;
  final String? error;

  const BusinessState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  BusinessState copyWith({
    List<BusinessDetail>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      BusinessState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class BusinessNotifier extends StateNotifier<BusinessState> {
  final BusinessService _service;

  BusinessNotifier(this._service) : super(const BusinessState()) {
    Future.microtask(load);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _service.fetchAll();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<BusinessDetail?> create({
    required String name,
    required String currency,
    String? type,
    String? address,
    String? phone,
    String? email,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final created = await _service.create(
        name: name,
        currency: currency,
        type: type,
        address: address,
        phone: phone,
        email: email,
      );
      state = state.copyWith(
        items: [created, ...state.items],
        isLoading: false,
      );
      return created;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> update(
    String id, {
    required String name,
    required String currency,
    String? type,
    String? address,
    String? phone,
    String? email,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _service.update(
        id,
        name: name,
        currency: currency,
        type: type,
        address: address,
        phone: phone,
        email: email,
      );
      state = state.copyWith(
        items: state.items
            .map((b) => b.id == id ? updated : b)
            .toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> delete(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.delete(id);
      state = state.copyWith(
        items: state.items.where((b) => b.id != id).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final businessServiceProvider =
    Provider<BusinessService>((ref) => BusinessService());

final businessProvider =
    StateNotifierProvider<BusinessNotifier, BusinessState>(
  (ref) => BusinessNotifier(ref.watch(businessServiceProvider)),
);
