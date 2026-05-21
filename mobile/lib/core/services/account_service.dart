import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/account_model.dart';

class AccountService {
  final Dio _dio = ApiClient.instance;

  Future<List<AccountItem>> fetchAll() async {
    try {
      final r = await _dio.get('/api/accounts');
      return (r.data['items'] as List)
          .map((j) => AccountItem.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<AccountItem> create({
    required AccountType type,
    required String accountName,
    String? bankName,
    String? accountNumber,
    double openingBalance = 0,
  }) async {
    try {
      final r = await _dio.post('/api/accounts', data: {
        'type': type.apiValue,
        'accountName': accountName,
        if (bankName != null && bankName.isNotEmpty) 'bankName': bankName,
        if (accountNumber != null && accountNumber.isNotEmpty)
          'accountNumber': accountNumber,
        'openingBalance': openingBalance,
      });
      return AccountItem.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<AccountItem> update(
    String id, {
    AccountType? type,
    String? accountName,
    String? bankName,
    String? accountNumber,
  }) async {
    try {
      final body = <String, dynamic>{
        if (type != null) 'type': type.apiValue,
        if (accountName != null) 'accountName': accountName,
        if (bankName != null) 'bankName': bankName.isEmpty ? null : bankName,
        if (accountNumber != null)
          'accountNumber': accountNumber.isEmpty ? null : accountNumber,
      };
      final r = await _dio.patch('/api/accounts/$id', data: body);
      return AccountItem.fromJson(r.data['item'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/api/accounts/$id');
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }
}
