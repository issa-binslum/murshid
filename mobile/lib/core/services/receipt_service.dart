import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/receipt_model.dart';

class ReceiptService {
  final Dio _dio = ApiClient.instance;

  Future<List<Receipt>> fetchAll() async {
    try {
      final r = await _dio.get('/api/receipts');
      return (r.data['items'] as List)
          .map((j) => Receipt.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<Receipt> create({
    required DateTime date,
    required String accountId,
    required double amount,
    String? paidBy,
    String? customerId,
    String? description,
    List<Map<String, dynamic>> items = const [],
  }) async {
    try {
      final r = await _dio.post('/api/receipts', data: {
        'date': date.toIso8601String(),
        'accountId': accountId,
        'amount': amount,
        if (paidBy != null && paidBy.isNotEmpty) 'paidBy': paidBy,
        if (customerId != null) 'customerId': customerId,
        if (description != null && description.isNotEmpty)
          'description': description,
        'items': items,
      });
      return Receipt.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<Receipt> update(
    String id, {
    DateTime? date,
    String? paidBy,
    String? accountId,
    double? amount,
    String? description,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final r = await _dio.patch('/api/receipts/$id', data: {
        if (date != null) 'date': date.toIso8601String(),
        if (paidBy != null) 'paidBy': paidBy.isEmpty ? null : paidBy,
        if (accountId != null) 'accountId': accountId,
        if (amount != null) 'amount': amount,
        if (description != null)
          'description': description.isEmpty ? null : description,
        if (items != null) 'items': items,
      });
      return Receipt.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/api/receipts/$id');
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }
}
