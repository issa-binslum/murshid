import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account_model.dart';
import '../services/account_service.dart';

class AccountState {
  final List<AccountItem> items;
  final bool isLoading;
  final String? error;

  const AccountState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  AccountState copyWith({
    List<AccountItem>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      AccountState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class AccountNotifier extends StateNotifier<AccountState> {
  final AccountService _svc;

  AccountNotifier(this._svc) : super(const AccountState()) {
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
    required AccountType type,
    required String accountName,
    String? bankName,
    String? accountNumber,
    double openingBalance = 0,
  }) async {
    try {
      final item = await _svc.create(
        type: type,
        accountName: accountName,
        bankName: bankName,
        accountNumber: accountNumber,
        openingBalance: openingBalance,
      );
      state = state.copyWith(items: [...state.items, item]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> update(
    String id, {
    AccountType? type,
    String? accountName,
    String? bankName,
    String? accountNumber,
  }) async {
    try {
      final updated = await _svc.update(
        id,
        type: type,
        accountName: accountName,
        bankName: bankName,
        accountNumber: accountNumber,
      );
      state = state.copyWith(
        items: state.items.map((a) => a.id == id ? updated : a).toList(),
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
        items: state.items.where((a) => a.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final accountServiceProvider =
    Provider<AccountService>((ref) => AccountService());

final accountProvider =
    StateNotifierProvider<AccountNotifier, AccountState>(
  (ref) => AccountNotifier(ref.watch(accountServiceProvider)),
);
