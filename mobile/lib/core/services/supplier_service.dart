import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/supplier_model.dart';

class SupplierService {
  final Dio _dio = ApiClient.instance;

  Future<List<Supplier>> fetchAll({String? q}) async {
    try {
      final r = await _dio.get(
        '/api/suppliers',
        queryParameters:
            (q != null && q.isNotEmpty) ? {'q': q} : null,
      );
      return (r.data['items'] as List)
          .map((j) => Supplier.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<Supplier> create({
    required String name,
    String? phone,
    String? email,
    String? address,
    double creditLimit = 0,
  }) async {
    try {
      final r = await _dio.post('/api/suppliers', data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (address != null && address.isNotEmpty) 'address': address,
        'creditLimit': creditLimit,
      });
      return Supplier.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<Supplier> update(
    String id, {
    String? name,
    String? phone,
    String? email,
    String? address,
    double? creditLimit,
  }) async {
    try {
      final body = <String, dynamic>{
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone.isEmpty ? null : phone,
        if (email != null) 'email': email.isEmpty ? null : email,
        if (address != null) 'address': address.isEmpty ? null : address,
        if (creditLimit != null) 'creditLimit': creditLimit,
      };
      final r = await _dio.patch('/api/suppliers/$id', data: body);
      return Supplier.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/api/suppliers/$id');
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }
}
