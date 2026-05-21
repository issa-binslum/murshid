import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/sales_model.dart';

class SalesOrderService {
  final Dio _dio = ApiClient.instance;

  Future<List<SalesOrder>> fetchAll() async {
    try {
      final r = await _dio.get('/api/sales/orders');
      return (r.data['items'] as List)
          .map((j) => SalesOrder.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<SalesOrder> create({
    required String customerId,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    String? address,
    String? description,
  }) async {
    try {
      final r = await _dio.post('/api/sales/orders', data: {
        'customerId': customerId,
        'date': date.toIso8601String(),
        'items': items,
        if (address != null && address.isNotEmpty) 'address': address,
        if (description != null && description.isNotEmpty)
          'description': description,
      });
      return SalesOrder.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<SalesOrder> update(
    String id, {
    String? customerId,
    DateTime? date,
    List<Map<String, dynamic>>? items,
    String? address,
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{
        if (customerId != null) 'customerId': customerId,
        if (date != null) 'date': date.toIso8601String(),
        if (items != null) 'items': items,
        if (address != null) 'address': address.isEmpty ? null : address,
        if (description != null)
          'description': description.isEmpty ? null : description,
      };
      final r = await _dio.patch('/api/sales/orders/$id', data: body);
      return SalesOrder.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _dio.delete('/api/sales/orders/$id');
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }
}

class SalesInvoiceService {
  final Dio _dio = ApiClient.instance;

  Future<List<SalesInvoice>> fetchAll() async {
    try {
      final r = await _dio.get('/api/sales/invoices');
      return (r.data['items'] as List)
          .map((j) => SalesInvoice.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<SalesInvoice> create({
    required String customerId,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    String? description,
  }) async {
    try {
      final r = await _dio.post('/api/sales/invoices', data: {
        'customerId': customerId,
        'date': date.toIso8601String(),
        'items': items,
        if (description != null && description.isNotEmpty)
          'description': description,
      });
      return SalesInvoice.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<SalesInvoice> update(
    String id, {
    String? customerId,
    DateTime? date,
    List<Map<String, dynamic>>? items,
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{
        if (customerId != null) 'customerId': customerId,
        if (date != null) 'date': date.toIso8601String(),
        if (items != null) 'items': items,
        if (description != null)
          'description': description.isEmpty ? null : description,
      };
      final r = await _dio.patch('/api/sales/invoices/$id', data: body);
      return SalesInvoice.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<SalesInvoice> markPaid(String id) async {
    try {
      final r = await _dio.post('/api/sales/invoices/$id/mark-paid');
      return SalesInvoice.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _dio.delete('/api/sales/invoices/$id');
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }
}
