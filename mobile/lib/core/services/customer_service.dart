import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/customer_model.dart';

class CustomerService {
  final Dio _dio = ApiClient.instance;

  Future<List<Customer>> fetchAll({String? q}) async {
    try {
      final r = await _dio.get(
        '/api/customers',
        queryParameters:
            (q != null && q.isNotEmpty) ? {'q': q} : null,
      );
      return (r.data['items'] as List)
          .map((j) => Customer.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<Customer> create({
    required String name,
    String? phone,
    String? email,
    String? billingAddress,
    String? deliveryAddress,
    double creditLimit = 0,
  }) async {
    try {
      final r = await _dio.post('/api/customers', data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (billingAddress != null && billingAddress.isNotEmpty)
          'billingAddress': billingAddress,
        if (deliveryAddress != null && deliveryAddress.isNotEmpty)
          'deliveryAddress': deliveryAddress,
        'creditLimit': creditLimit,
      });
      return Customer.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<Customer> update(
    String id, {
    String? name,
    String? phone,
    String? email,
    String? billingAddress,
    String? deliveryAddress,
    double? creditLimit,
  }) async {
    try {
      final body = <String, dynamic>{
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone.isEmpty ? null : phone,
        if (email != null) 'email': email.isEmpty ? null : email,
        if (billingAddress != null)
          'billingAddress':
              billingAddress.isEmpty ? null : billingAddress,
        if (deliveryAddress != null)
          'deliveryAddress':
              deliveryAddress.isEmpty ? null : deliveryAddress,
        if (creditLimit != null) 'creditLimit': creditLimit,
      };
      final r = await _dio.patch('/api/customers/$id', data: body);
      return Customer.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/api/customers/$id');
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }
}
