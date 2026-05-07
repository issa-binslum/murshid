import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/storage/secure_kv.dart';

class BusinessMembership {
  const BusinessMembership({
    required this.businessId,
    required this.businessName,
    required this.roleId,
    required this.roleName,
    required this.currency,
  });

  final String businessId;
  final String businessName;
  final String roleId;
  final String roleName;
  final String currency;
}

class AuthState {
  const AuthState({
    required this.isLoggedIn,
    required this.preAuthToken,
    required this.accessToken,
    required this.businesses,
  });

  final bool isLoggedIn;
  final String? preAuthToken;
  final String? accessToken;
  final List<BusinessMembership> businesses;

  AuthState copyWith({
    bool? isLoggedIn,
    String? preAuthToken,
    String? accessToken,
    List<BusinessMembership>? businesses,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      preAuthToken: preAuthToken ?? this.preAuthToken,
      accessToken: accessToken ?? this.accessToken,
      businesses: businesses ?? this.businesses,
    );
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    api: ref.read(apiClientProvider),
    secure: ref.read(secureKvProvider),
  );
});

class AuthController extends StateNotifier<AuthState> {
  AuthController({required this.api, required this.secure})
      : super(const AuthState(
            isLoggedIn: false,
            preAuthToken: null,
            accessToken: null,
            businesses: []));

  final ApiClient api;
  final SecureKv secure;

  Future<void> login(
      {required String identifier, required String password}) async {
    final res = await api.login(identifier: identifier, password: password);
    state = state.copyWith(
      isLoggedIn: true,
      preAuthToken: res.preAuthToken,
      accessToken: null,
      businesses: res.businesses,
    );
    await secure.write('preAuthToken', res.preAuthToken);
  }

  Future<void> switchBusiness(String businessId) async {
    final token = state.preAuthToken ?? await secure.read('preAuthToken');
    if (token == null) {
      state = const AuthState(
          isLoggedIn: false,
          preAuthToken: null,
          accessToken: null,
          businesses: []);
      return;
    }
    try {
      final res =
          await api.switchBusiness(preAuthToken: token, businessId: businessId);
      state = state.copyWith(accessToken: res.accessToken);
      await secure.write('accessToken', res.accessToken);
      print('Switch business successful, accessToken: ${res.accessToken}');
    } catch (e) {
      print('Switch business failed: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    state = const AuthState(
        isLoggedIn: false,
        preAuthToken: null,
        accessToken: null,
        businesses: []);
    await secure.delete('preAuthToken');
    await secure.delete('accessToken');
  }
}
