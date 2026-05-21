import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/payment_model.dart';

class PaymentService {
  final Dio _dio = ApiClient.instance;

  Future<List<Payment>> fetchAll() async {
    try {
      final r = await _dio.get('/api/payments');
      return (r.data['items'] as List)
          .map((j) => Payment.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<Payment> create({
    required DateTime date,
    required String accountId,
    required double amount,
    String? payee,
    String? supplierId,
    String? description,
  }) async {
    try {
      final r = await _dio.post('/api/payments', data: {
        'date': date.toIso8601String(),
        'accountId': accountId,
        'amount': amount,
        if (payee != null && payee.isNotEmpty) 'payee': payee,
        if (supplierId != null) 'supplierId': supplierId,
        if (description != null && description.isNotEmpty)
          'description': description,
      });
      return Payment.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/api/payments/$id');
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }
}
