import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response_model.dart';
import '../models/business_model.dart';
import '../models/user_model.dart';
import 'api_client.dart';

class AuthService {
  // Step 1: send { identifier, password } → preAuthToken + businesses list
  Future<LoginResponse> login(String identifier, String password) async {
    try {
      final response = await ApiClient.instance.post(
        '/api/auth/login',
        data: {'identifier': identifier, 'password': password},
      );
      return LoginResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  // Step 2: exchange preAuthToken + businessId → accessToken + permissions
  // Uses [bearerToken] directly so the interceptor's stored token is bypassed.
  Future<SwitchBusinessResult> switchBusiness(
    String businessId,
    String bearerToken,
  ) async {
    try {
      final response = await ApiClient.instance.post(
        '/api/auth/switch-business',
        data: {'businessId': businessId},
        options: Options(headers: {'Authorization': 'Bearer $bearerToken'}),
      );
      final result =
          SwitchBusinessResult.fromJson(response.data as Map<String, dynamic>);
      await _persistSession(result);
      return result;
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // Tell the backend to revoke the token so it can't be reused.
    // Fire-and-forget: local logout always succeeds even if the call fails.
    if (token != null && token.isNotEmpty) {
      try {
        await ApiClient.instance.post(
          '/api/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } catch (_) {}
    }

    await prefs.clear();
  }

  Future<void> _persistSession(SwitchBusinessResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', result.accessToken);
    await prefs.setString('currentBusinessId', result.business.id);
    await prefs.setString('currentBusinessName', result.business.name);
    await prefs.setString('currentBusinessCurrency', result.business.currency);
    await prefs.setString('permissions', jsonEncode(result.permissions));
  }

  static Future<void> persistUserInfo(UserModel user, List<BusinessItem> businesses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', user.id);
    await prefs.setString('fullName', user.fullName);
    await prefs.setString('email', user.email);
    await prefs.setString('username', user.username);
    await prefs.setString(
      'businesses',
      jsonEncode(businesses.map((b) => b.toJson()).toList()),
    );
  }

  static Future<Map<String, dynamic>?> loadPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) return null;

    return {
      'token': token,
      'user': UserModel(
        id: prefs.getString('userId') ?? '',
        fullName: prefs.getString('fullName') ?? '',
        email: prefs.getString('email') ?? '',
        username: prefs.getString('username') ?? '',
      ),
      'currentBusiness': BusinessModel(
        id: prefs.getString('currentBusinessId') ?? '',
        name: prefs.getString('currentBusinessName') ?? '',
        currency: prefs.getString('currentBusinessCurrency') ?? 'USD',
      ),
      'permissions':
          (jsonDecode(prefs.getString('permissions') ?? '[]') as List<dynamic>)
              .cast<String>(),
      'businesses':
          (jsonDecode(prefs.getString('businesses') ?? '[]') as List<dynamic>)
              .map((b) => BusinessItem.fromJson(b as Map<String, dynamic>))
              .toList(),
    };
  }
}
