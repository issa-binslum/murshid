import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/inventory_model.dart';

class InventoryService {
  final Dio _dio = ApiClient.instance;

  Future<List<InventoryItem>> fetchAll({String? q}) async {
    try {
      final r = await _dio.get(
        '/api/inventory',
        queryParameters:
            (q != null && q.isNotEmpty) ? {'q': q} : null,
      );
      return (r.data['items'] as List)
          .map((j) => InventoryItem.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<InventoryItem> create({
    required String itemCode,
    required String itemName,
    required String unitName,
    double purchasePrice = 0,
    double salesPrice = 0,
    double lowStockLevel = 0,
    double quantity = 0,
    String? description,
  }) async {
    try {
      final r = await _dio.post('/api/inventory', data: {
        'itemCode': itemCode,
        'itemName': itemName,
        'unitName': unitName,
        'purchasePrice': purchasePrice,
        'salesPrice': salesPrice,
        'lowStockLevel': lowStockLevel,
        'quantity': quantity,
        if (description != null && description.isNotEmpty)
          'description': description,
      });
      return InventoryItem.fromJson(
          r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<InventoryItem> update(
    String id, {
    String? itemCode,
    String? itemName,
    String? unitName,
    double? purchasePrice,
    double? salesPrice,
    double? lowStockLevel,
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{
        if (itemCode != null) 'itemCode': itemCode,
        if (itemName != null) 'itemName': itemName,
        if (unitName != null) 'unitName': unitName,
        if (purchasePrice != null) 'purchasePrice': purchasePrice,
        if (salesPrice != null) 'salesPrice': salesPrice,
        if (lowStockLevel != null) 'lowStockLevel': lowStockLevel,
        if (description != null)
          'description': description.isEmpty ? null : description,
      };
      final r = await _dio.patch('/api/inventory/$id', data: body);
      return InventoryItem.fromJson(
          r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/api/inventory/$id');
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }
}
