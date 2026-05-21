import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_response_model.dart';
import '../models/business_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'account_provider.dart';
import 'audit_provider.dart';
import 'business_provider.dart';
import 'customer_provider.dart';
import 'inventory_provider.dart';
import 'payment_provider.dart';
import 'purchase_provider.dart';
import 'receipt_provider.dart';
import 'sales_provider.dart';
import 'sidebar_provider.dart';
import 'supplier_provider.dart';
import 'user_provider.dart';

class AuthState {
  /// Full access token (set after switch-business completes).
  final String? token;

  /// Temporary token valid only for calling switch-business.
  final String? preAuthToken;

  final UserModel? user;
  final BusinessModel? currentBusiness;
  final List<String> permissions;

  /// All businesses this user belongs to (from login step 1).
  final List<BusinessItem> businesses;

  final bool isLoading;
  final String? error;

  const AuthState({
    this.token,
    this.preAuthToken,
    this.user,
    this.currentBusiness,
    this.permissions = const [],
    this.businesses = const [],
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  /// True when the user has authenticated but still needs to pick a business.
  bool get needsBusinessSelection =>
      preAuthToken != null && token == null && businesses.length > 1;

  bool hasPermission(String key) => permissions.contains(key);

  AuthState copyWith({
    String? token,
    String? preAuthToken,
    UserModel? user,
    BusinessModel? currentBusiness,
    List<String>? permissions,
    List<BusinessItem>? businesses,
    bool? isLoading,
    String? error,
    bool clearPreAuthToken = false,
    bool clearError = false,
  }) =>
      AuthState(
        token: token ?? this.token,
        preAuthToken:
            clearPreAuthToken ? null : (preAuthToken ?? this.preAuthToken),
        user: user ?? this.user,
        currentBusiness: currentBusiness ?? this.currentBusiness,
        permissions: permissions ?? this.permissions,
        businesses: businesses ?? this.businesses,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _service;
  final Ref _ref;

  AuthNotifier(this._service, this._ref) : super(const AuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final data = await AuthService.loadPersistedSession();
    if (data != null) {
      state = AuthState(
        token: data['token'] as String,
        user: data['user'] as UserModel,
        currentBusiness: data['currentBusiness'] as BusinessModel,
        permissions: data['permissions'] as List<String>,
        businesses: data['businesses'] as List<BusinessItem>,
      );
    }
  }

  /// Step 1 of auth: sends identifier + password.
  /// If user belongs to exactly one business, auto-completes step 2.
  /// If multiple businesses, sets [needsBusinessSelection] = true.
  Future<bool> login(String identifier, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final loginResponse = await _service.login(identifier, password);

      // Persist user info so it survives an app restart between steps.
      await AuthService.persistUserInfo(loginResponse.user, loginResponse.businesses);

      if (loginResponse.businesses.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'No business assigned to this account.',
        );
        return false;
      }

      // Hold the preAuthToken and user info; businesses list available for picker.
      state = AuthState(
        preAuthToken: loginResponse.preAuthToken,
        user: loginResponse.user,
        businesses: loginResponse.businesses,
        isLoading: loginResponse.businesses.length > 1,
      );

      if (loginResponse.businesses.length == 1) {
        // Auto-select the only business.
        return await selectBusiness(loginResponse.businesses.first.businessId);
      }

      // Multiple businesses — caller must show picker, then call selectBusiness().
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Step 2: pick a business (or switch from sidebar switcher).
  Future<bool> selectBusiness(String businessId) async {
    final bearer = state.preAuthToken ?? state.token;
    if (bearer == null) {
      state = state.copyWith(error: 'Session expired. Please log in again.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.switchBusiness(businessId, bearer);
      state = AuthState(
        token: result.accessToken,
        user: state.user,
        currentBusiness: result.business,
        permissions: result.permissions,
        businesses: state.businesses,
      );
      _invalidateBusinessData();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Called after a business is created so the sidebar switcher shows it immediately.
  void addBusiness(BusinessItem item) {
    state = state.copyWith(businesses: [...state.businesses, item]);
  }

  /// Called after a business is deleted so the switcher removes it immediately.
  void removeBusiness(String businessId) {
    state = state.copyWith(
      businesses: state.businesses.where((b) => b.businessId != businessId).toList(),
    );
  }

  Future<void> logout() async {
    await _service.logout();
    state = const AuthState();
    _invalidateBusinessData();
  }

  void _invalidateBusinessData() {
    _ref.invalidate(accountProvider);
    _ref.invalidate(auditProvider);
    _ref.invalidate(businessProvider);
    _ref.invalidate(customerProvider);
    _ref.invalidate(inventoryProvider);
    _ref.invalidate(paymentProvider);
    _ref.invalidate(purchaseOrderProvider);
    _ref.invalidate(purchaseInvoiceProvider);
    _ref.invalidate(receiptProvider);
    _ref.invalidate(salesOrderProvider);
    _ref.invalidate(salesInvoiceProvider);
    _ref.invalidate(supplierProvider);
    _ref.invalidate(userProvider);
    _ref.invalidate(sidebarCollapsedProvider);
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authServiceProvider), ref),
);
