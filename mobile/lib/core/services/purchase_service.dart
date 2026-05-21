import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/purchase_model.dart';

class PurchaseOrderService {
  final Dio _dio = ApiClient.instance;

  Future<List<PurchaseOrder>> fetchAll() async {
    try {
      final r = await _dio.get('/api/purchases/orders');
      return (r.data['items'] as List)
          .map((j) => PurchaseOrder.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<PurchaseOrder> create({
    required String supplierId,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    String? description,
  }) async {
    try {
      final r = await _dio.post('/api/purchases/orders', data: {
        'supplierId': supplierId,
        'date': date.toIso8601String(),
        'items': items,
        if (description != null && description.isNotEmpty)
          'description': description,
      });
      return PurchaseOrder.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<PurchaseOrder> update(
    String id, {
    String? supplierId,
    DateTime? date,
    List<Map<String, dynamic>>? items,
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{
        if (supplierId != null) 'supplierId': supplierId,
        if (date != null) 'date': date.toIso8601String(),
        if (items != null) 'items': items,
        if (description != null)
          'description': description.isEmpty ? null : description,
      };
      final r = await _dio.patch('/api/purchases/orders/$id', data: body);
      return PurchaseOrder.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _dio.delete('/api/purchases/orders/$id');
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }
}

class PurchaseInvoiceService {
  final Dio _dio = ApiClient.instance;

  Future<List<PurchaseInvoice>> fetchAll() async {
    try {
      final r = await _dio.get('/api/purchases/invoices');
      return (r.data['items'] as List)
          .map((j) => PurchaseInvoice.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<PurchaseInvoice> create({
    required String supplierId,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    String? description,
  }) async {
    try {
      final r = await _dio.post('/api/purchases/invoices', data: {
        'supplierId': supplierId,
        'date': date.toIso8601String(),
        'items': items,
        if (description != null && description.isNotEmpty)
          'description': description,
      });
      return PurchaseInvoice.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<PurchaseInvoice> update(
    String id, {
    String? supplierId,
    DateTime? date,
    List<Map<String, dynamic>>? items,
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{
        if (supplierId != null) 'supplierId': supplierId,
        if (date != null) 'date': date.toIso8601String(),
        if (items != null) 'items': items,
        if (description != null)
          'description': description.isEmpty ? null : description,
      };
      final r = await _dio.patch('/api/purchases/invoices/$id', data: body);
      return PurchaseInvoice.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<PurchaseInvoice> markPaid(String id) async {
    try {
      final r = await _dio.post('/api/purchases/invoices/$id/mark-paid');
      return PurchaseInvoice.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _dio.delete('/api/purchases/invoices/$id');
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }
}
