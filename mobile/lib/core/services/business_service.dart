import 'package:dio/dio.dart';
import '../models/business_detail_model.dart';
import 'api_client.dart';

class BusinessService {
  Future<List<BusinessDetail>> fetchAll() async {
    try {
      final res = await ApiClient.instance.get('/api/businesses');
      final items = (res.data['items'] as List<dynamic>);
      return items
          .map((e) => BusinessDetail.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<BusinessDetail> create({
    required String name,
    required String currency,
    String? type,
    String? address,
    String? phone,
    String? email,
  }) async {
    try {
      final res = await ApiClient.instance.post('/api/businesses', data: {
        'name': name,
        'currency': currency,
        if (type != null && type.isNotEmpty) 'type': type,
        if (address != null && address.isNotEmpty) 'address': address,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      return BusinessDetail.fromJson(res.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<BusinessDetail> update(
    String id, {
    String? name,
    String? currency,
    String? type,
    String? address,
    String? phone,
    String? email,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (currency != null) body['currency'] = currency;
      if (type != null) body['type'] = type.isEmpty ? null : type;
      if (address != null) body['address'] = address.isEmpty ? null : address;
      if (phone != null) body['phone'] = phone.isEmpty ? null : phone;
      if (email != null) body['email'] = email.isEmpty ? null : email;

      final res =
          await ApiClient.instance.patch('/api/businesses/$id', data: body);
      return BusinessDetail.fromJson(res.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await ApiClient.instance.delete('/api/businesses/$id');
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }
}
