import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/audit_model.dart';

class AuditResult {
  final List<AuditEntry> items;
  final int total;
  final int page;
  final int limit;

  const AuditResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });
}

class AuditService {
  final Dio _dio = ApiClient.instance;

  Future<AuditResult> fetch({
    int page = 1,
    int limit = 25,
    String? entity,
    String? action,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (entity != null && entity.isNotEmpty) 'entity': entity,
        if (action != null && action.isNotEmpty) 'action': action,
        if (search != null && search.isNotEmpty) 'search': search,
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      };
      final r = await _dio.get('/api/audit', queryParameters: params);
      final items = (r.data['items'] as List)
          .map((j) => AuditEntry.fromJson(j as Map<String, dynamic>))
          .toList();
      return AuditResult(
        items: items,
        total: r.data['total'] as int,
        page: r.data['page'] as int,
        limit: r.data['limit'] as int,
      );
    } on DioException catch (e) {
      throw ApiClient.extractMessage(e);
    }
  }
}
