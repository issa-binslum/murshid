import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_item_model.dart';
import '../services/user_service.dart';

class UserState {
  final List<UserItem> items;
  final List<PermissionItem> availablePermissions;
  final bool isLoading;
  final String? error;

  const UserState({
    this.items = const [],
    this.availablePermissions = const [],
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    List<UserItem>? items,
    List<PermissionItem>? availablePermissions,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      UserState(
        items: items ?? this.items,
        availablePermissions: availablePermissions ?? this.availablePermissions,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class UserNotifier extends StateNotifier<UserState> {
  final UserService _svc;

  UserNotifier(this._svc) : super(const UserState()) {
    Future.microtask(load);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results =
          await Future.wait([_svc.fetchAll(), _svc.fetchPermissions()]);
      state = state.copyWith(
        items: results[0] as List<UserItem>,
        availablePermissions: results[1] as List<PermissionItem>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> create({
    required String fullName,
    required String email,
    required String username,
    required String password,
    required List<String> permissions,
    String? phone,
    String status = 'ACTIVE',
  }) async {
    try {
      final item = await _svc.create(
        fullName: fullName,
        email: email,
        username: username,
        password: password,
        permissions: permissions,
        phone: phone,
        status: status,
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
    String? fullName,
    String? email,
    String? username,
    String? password,
    String? phone,
    String? status,
    List<String>? permissions,
  }) async {
    try {
      final updated = await _svc.update(
        id,
        fullName: fullName,
        email: email,
        username: username,
        password: password,
        phone: phone,
        status: status,
        permissions: permissions,
      );
      state = state.copyWith(
        items: state.items.map((u) => u.id == id ? updated : u).toList(),
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
        items: state.items.where((u) => u.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final userServiceProvider = Provider<UserService>((ref) => UserService());

final userProvider = StateNotifierProvider<UserNotifier, UserState>(
  (ref) => UserNotifier(ref.watch(userServiceProvider)),
);
