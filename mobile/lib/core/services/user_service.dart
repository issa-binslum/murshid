import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/user_item_model.dart';

class UserService {
  final Dio _dio = ApiClient.instance;

  Future<List<UserItem>> fetchAll() async {
    try {
      final r = await _dio.get('/api/users');
      return (r.data['items'] as List)
          .map((j) => UserItem.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<List<PermissionItem>> fetchPermissions() async {
    try {
      final r = await _dio.get('/api/users/permissions');
      return (r.data['items'] as List)
          .map((j) => PermissionItem.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<UserItem> create({
    required String fullName,
    required String email,
    required String username,
    required String password,
    required List<String> permissions,
    String? phone,
    String status = 'ACTIVE',
  }) async {
    try {
      final r = await _dio.post('/api/users', data: {
        'fullName': fullName,
        'email': email,
        'username': username,
        'password': password,
        'permissions': permissions,
        'status': status,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });
      return UserItem.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<UserItem> update(
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
      final body = <String, dynamic>{
        if (fullName != null) 'fullName': fullName,
        if (email != null) 'email': email,
        if (username != null) 'username': username,
        if (password != null && password.isNotEmpty) 'password': password,
        if (phone != null) 'phone': phone.isEmpty ? null : phone,
        if (status != null) 'status': status,
        if (permissions != null) 'permissions': permissions,
      };
      final r = await _dio.patch('/api/users/$id', data: body);
      return UserItem.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/api/users/$id');
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }
}
