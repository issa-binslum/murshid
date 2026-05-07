import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(Dio(BaseOptions(baseUrl: 'http://localhost:4000')));
});

class LoginResult {
  const LoginResult({required this.preAuthToken, required this.businesses});

  final String preAuthToken;
  final List<BusinessMembership> businesses;
}

class SwitchBusinessResult {
  const SwitchBusinessResult({required this.accessToken});

  final String accessToken;
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalSales,
    required this.totalPurchases,
    required this.totalReceipts,
    required this.totalPayments,
    required this.customersCount,
    required this.suppliersCount,
    required this.lowStockItemsCount,
  });

  final num totalSales;
  final num totalPurchases;
  final num totalReceipts;
  final num totalPayments;
  final int customersCount;
  final int suppliersCount;
  final int lowStockItemsCount;
}

class Account {
  const Account({
    required this.id,
    required this.accountName,
    required this.type,
    required this.bankName,
    required this.accountNumber,
    required this.openingBalance,
    required this.currentBalance,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String accountName;
  final String type; // 'BANK', 'CASH', 'MOBILE_WALLET'
  final String? bankName;
  final String? accountNumber;
  final num openingBalance;
  final num currentBalance;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.lowStockLevel,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final num quantity;
  final String unit;
  final num lowStockLevel;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.itemId,
    required this.type,
    required this.quantity,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String itemId;
  final String type; // 'in', 'out', 'adjust'
  final num quantity;
  final String reason;
  final DateTime createdAt;
}

class Receipt {
  const Receipt({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String accountId;
  final num amount;
  final String description;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Payment {
  const Payment({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String accountId;
  final num amount;
  final String description;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  List<Map<String, dynamic>> _extractItems(dynamic data) {
    if (data is List) {
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    if (data is Map<String, dynamic>) {
      final items = data['items'];
      if (items is List) {
        return items.map((e) => e as Map<String, dynamic>).toList();
      }
    }
    return const [];
  }

  num _coerceNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.parse(value);
    return 0;
  }

  Future<LoginResult> login(
      {required String identifier, required String password}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'identifier': identifier, 'password': password},
    );
    final data = res.data ?? const {};

    final businesses = (data['businesses'] as List<dynamic>? ?? const [])
        .map((e) => e as Map<String, dynamic>)
        .map(
          (e) => BusinessMembership(
            businessId: e['businessId'] as String,
            businessName: e['businessName'] as String,
            roleId: e['roleId'] as String,
            roleName: e['roleName'] as String,
            currency: e['currency'] as String,
          ),
        )
        .toList(growable: false);

    return LoginResult(
      preAuthToken: data['preAuthToken'] as String,
      businesses: businesses,
    );
  }

  Future<SwitchBusinessResult> switchBusiness({
    required String preAuthToken,
    required String businessId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/auth/switch-business',
      data: {'businessId': businessId},
      options: Options(headers: {'Authorization': 'Bearer $preAuthToken'}),
    );
    final data = res.data ?? const {};
    return SwitchBusinessResult(accessToken: data['accessToken'] as String);
  }

  Future<DashboardSummary> dashboardSummary(
      {required String accessToken}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/dashboard/summary',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = res.data ?? const {};
    final totals = (data['totals'] as Map<String, dynamic>? ?? const {});
    final counts = (data['counts'] as Map<String, dynamic>? ?? const {});
    num _toNum(dynamic value) {
      if (value is num) return value;
      if (value is String) return num.parse(value);
      return 0;
    }

    int _toInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.parse(value);
      if (value is num) return value.toInt();
      return 0;
    }

    return DashboardSummary(
      totalSales: _toNum(totals['sales']),
      totalPurchases: _toNum(totals['purchases']),
      totalReceipts: _toNum(totals['receipts']),
      totalPayments: _toNum(totals['payments']),
      customersCount: _toInt(counts['customers']),
      suppliersCount: _toInt(counts['suppliers']),
      lowStockItemsCount: _toInt(counts['lowStockItems']),
    );
  }

  // Accounts
  Future<List<Account>> getAccounts(
      {required String accessToken, String? q}) async {
    final res = await _dio.get<dynamic>(
      '/api/accounts',
      queryParameters: q != null ? {'q': q} : null,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractItems(res.data);
    return data
        .map((e) => e as Map<String, dynamic>)
        .map((e) => Account(
              id: e['id'] as String,
              accountName: e['accountName'] as String,
              type: e['type'] as String,
              bankName: e['bankName'] as String?,
              accountNumber: e['accountNumber'] as String?,
              openingBalance: _coerceNum(e['openingBalance']),
              currentBalance: _coerceNum(e['currentBalance']),
              createdAt: DateTime.parse(e['createdAt'] as String),
              updatedAt: DateTime.parse(e['updatedAt'] as String),
            ))
        .toList();
  }

  Future<Account> createAccount({
    required String accessToken,
    required String accountName,
    required String type,
    String? bankName,
    String? accountNumber,
    required num openingBalance,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/accounts',
      data: {
        'accountName': accountName,
        'type': type,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'openingBalance': openingBalance,
      }..removeWhere((k, v) => v == null),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = res.data!['item'] as Map<String, dynamic>;
    return Account(
      id: data['id'] as String,
      accountName: data['accountName'] as String,
      type: data['type'] as String,
      bankName: data['bankName'] as String?,
      accountNumber: data['accountNumber'] as String?,
      openingBalance: _coerceNum(data['openingBalance']),
      currentBalance: _coerceNum(data['currentBalance']),
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }

  Future<Account> updateAccount({
    required String accessToken,
    required String id,
    String? accountName,
    String? type,
    String? bankName,
    String? accountNumber,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/accounts/$id',
      data: {
        'accountName': accountName,
        'type': type,
        'bankName': bankName,
        'accountNumber': accountNumber,
      }..removeWhere((k, v) => v == null),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = res.data!['item'] as Map<String, dynamic>;
    return Account(
      id: data['id'] as String,
      accountName: data['accountName'] as String,
      type: data['type'] as String,
      bankName: data['bankName'] as String?,
      accountNumber: data['accountNumber'] as String?,
      openingBalance: _coerceNum(data['openingBalance']),
      currentBalance: _coerceNum(data['currentBalance']),
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }

  Future<void> deleteAccount(
      {required String accessToken, required String id}) async {
    await _dio.delete(
      '/api/accounts/$id',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  // Customers
  Future<List<Customer>> getCustomers(
      {required String accessToken, String? q}) async {
    final res = await _dio.get<dynamic>(
      '/api/customers',
      queryParameters: q != null ? {'q': q} : null,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractItems(res.data);
    return data
        .map((e) => e as Map<String, dynamic>)
        .map((e) => Customer(
              id: e['id'] as String,
              name: e['name'] as String,
              phone: e['phone'] as String?,
              email: e['email'] as String?,
              address: e['address'] as String?,
              createdAt: DateTime.parse(e['createdAt'] as String),
              updatedAt: DateTime.parse(e['updatedAt'] as String),
            ))
        .toList();
  }

  Future<Customer> createCustomer({
    required String accessToken,
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/customers',
      data: {'name': name, 'phone': phone, 'email': email, 'address': address}
        ..removeWhere((k, v) => v == null),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = res.data!['item'] as Map<String, dynamic>;
    return Customer(
      id: data['id'] as String,
      name: data['name'] as String,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }

  Future<Customer> updateCustomer({
    required String accessToken,
    required String id,
    String? name,
    String? phone,
    String? email,
    String? address,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/customers/$id',
      data: {'name': name, 'phone': phone, 'email': email, 'address': address}
        ..removeWhere((k, v) => v == null),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = res.data!['item'] as Map<String, dynamic>;
    return Customer(
      id: data['id'] as String,
      name: data['name'] as String,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }

  Future<void> deleteCustomer(
      {required String accessToken, required String id}) async {
    await _dio.delete(
      '/api/customers/$id',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  // Suppliers (similar to customers)
  Future<List<Supplier>> getSuppliers(
      {required String accessToken, String? q}) async {
    final res = await _dio.get<dynamic>(
      '/api/suppliers',
      queryParameters: q != null ? {'q': q} : null,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractItems(res.data);
    return data
        .map((e) => e as Map<String, dynamic>)
        .map((e) => Supplier(
              id: e['id'] as String,
              name: e['name'] as String,
              phone: e['phone'] as String?,
              email: e['email'] as String?,
              address: e['address'] as String?,
              createdAt: DateTime.parse(e['createdAt'] as String),
              updatedAt: DateTime.parse(e['updatedAt'] as String),
            ))
        .toList();
  }

  Future<Supplier> createSupplier({
    required String accessToken,
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/suppliers',
      data: {'name': name, 'phone': phone, 'email': email, 'address': address}
        ..removeWhere((k, v) => v == null),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = res.data!['item'] as Map<String, dynamic>;
    return Supplier(
      id: data['id'] as String,
      name: data['name'] as String,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }

  Future<Supplier> updateSupplier({
    required String accessToken,
    required String id,
    String? name,
    String? phone,
    String? email,
    String? address,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/suppliers/$id',
      data: {'name': name, 'phone': phone, 'email': email, 'address': address}
        ..removeWhere((k, v) => v == null),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = res.data!['item'] as Map<String, dynamic>;
    return Supplier(
      id: data['id'] as String,
      name: data['name'] as String,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }

  Future<void> deleteSupplier(
      {required String accessToken, required String id}) async {
    await _dio.delete(
      '/api/suppliers/$id',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  // Inventory
  Future<List<InventoryItem>> getInventory(
      {required String accessToken, String? q}) async {
    final res = await _dio.get<dynamic>(
      '/api/inventory',
      queryParameters: q != null ? {'q': q} : null,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractItems(res.data);
    return data
        .map((e) => e as Map<String, dynamic>)
        .map((e) => InventoryItem(
              id: e['id'] as String,
              name: e['name'] as String,
              description: e['description'] as String?,
              quantity: e['quantity'] as num,
              unit: e['unit'] as String,
              lowStockLevel: e['lowStockLevel'] as num,
              createdAt: DateTime.parse(e['createdAt'] as String),
              updatedAt: DateTime.parse(e['updatedAt'] as String),
            ))
        .toList();
  }

  Future<List<InventoryItem>> getLowStockInventory(
      {required String accessToken}) async {
    final res = await _dio.get<dynamic>(
      '/api/inventory/low-stock',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractItems(res.data);
    return data
        .map((e) => e as Map<String, dynamic>)
        .map((e) => InventoryItem(
              id: e['id'] as String,
              name: e['name'] as String,
              description: e['description'] as String?,
              quantity: e['quantity'] as num,
              unit: e['unit'] as String,
              lowStockLevel: e['lowStockLevel'] as num,
              createdAt: DateTime.parse(e['createdAt'] as String),
              updatedAt: DateTime.parse(e['updatedAt'] as String),
            ))
        .toList();
  }

  Future<List<InventoryMovement>> getInventoryMovements(
      {required String accessToken, required String itemId}) async {
    final res = await _dio.get<dynamic>(
      '/api/inventory/$itemId/movements',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractItems(res.data);
    return data
        .map((e) => e as Map<String, dynamic>)
        .map((e) => InventoryMovement(
              id: e['id'] as String,
              itemId: e['itemId'] as String,
              type: e['type'] as String,
              quantity: e['quantity'] as num,
              reason: e['reason'] as String,
              createdAt: DateTime.parse(e['createdAt'] as String),
            ))
        .toList();
  }

  Future<InventoryItem> createInventoryItem({
    required String accessToken,
    required String name,
    String? description,
    required num quantity,
    required String unit,
    required num lowStockLevel,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/inventory',
      data: {
        'name': name,
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'lowStockLevel': lowStockLevel
      }..removeWhere((k, v) => v == null),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = res.data!;
    return InventoryItem(
      id: data['id'] as String,
      name: data['name'] as String,
      description: data['description'] as String?,
      quantity: data['quantity'] as num,
      unit: data['unit'] as String,
      lowStockLevel: data['lowStockLevel'] as num,
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }

  Future<void> adjustInventory({
    required String accessToken,
    required String itemId,
    required num quantity,
    required String reason,
  }) async {
    await _dio.post(
      '/api/inventory/$itemId/adjust',
      data: {'quantity': quantity, 'reason': reason},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  Future<InventoryItem> updateInventoryItem({
    required String accessToken,
    required String id,
    String? name,
    String? description,
    num? lowStockLevel,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/inventory/$id',
      data: {
        'name': name,
        'description': description,
        'lowStockLevel': lowStockLevel
      }..removeWhere((k, v) => v == null),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = res.data!;
    return InventoryItem(
      id: data['id'] as String,
      name: data['name'] as String,
      description: data['description'] as String?,
      quantity: data['quantity'] as num,
      unit: data['unit'] as String,
      lowStockLevel: data['lowStockLevel'] as num,
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }

  Future<void> deleteInventoryItem(
      {required String accessToken, required String id}) async {
    await _dio.delete(
      '/api/inventory/$id',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  // Receipts
  Future<List<Receipt>> getReceipts({required String accessToken}) async {
    final res = await _dio.get<dynamic>(
      '/api/receipts',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractItems(res.data);
    return data
        .map((e) => e as Map<String, dynamic>)
        .map((e) => Receipt(
              id: e['id'] as String,
              accountId: e['accountId'] as String,
              amount: e['amount'] as num,
              description: e['description'] as String,
              date: DateTime.parse(e['date'] as String),
              createdAt: DateTime.parse(e['createdAt'] as String),
              updatedAt: DateTime.parse(e['updatedAt'] as String),
            ))
        .toList();
  }

  Future<Receipt> createReceipt({
    required String accessToken,
    required String accountId,
    required num amount,
    required String description,
    required DateTime date,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/receipts',
      data: {
        'accountId': accountId,
        'amount': amount,
        'description': description,
        'date': date.toIso8601String()
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = res.data!;
    return Receipt(
      id: data['id'] as String,
      accountId: data['accountId'] as String,
      amount: data['amount'] as num,
      description: data['description'] as String,
      date: DateTime.parse(data['date'] as String),
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }

  Future<void> deleteReceipt(
      {required String accessToken, required String id}) async {
    await _dio.delete(
      '/api/receipts/$id',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  // Payments (similar to receipts)
  Future<List<Payment>> getPayments({required String accessToken}) async {
    final res = await _dio.get<dynamic>(
      '/api/payments',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractItems(res.data);
    return data
        .map((e) => e as Map<String, dynamic>)
        .map((e) => Payment(
              id: e['id'] as String,
              accountId: e['accountId'] as String,
              amount: e['amount'] as num,
              description: e['description'] as String,
              date: DateTime.parse(e['date'] as String),
              createdAt: DateTime.parse(e['createdAt'] as String),
              updatedAt: DateTime.parse(e['updatedAt'] as String),
            ))
        .toList();
  }

  Future<Payment> createPayment({
    required String accessToken,
    required String accountId,
    required num amount,
    required String description,
    required DateTime date,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/payments',
      data: {
        'accountId': accountId,
        'amount': amount,
        'description': description,
        'date': date.toIso8601String()
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = res.data!;
    return Payment(
      id: data['id'] as String,
      accountId: data['accountId'] as String,
      amount: data['amount'] as num,
      description: data['description'] as String,
      date: DateTime.parse(data['date'] as String),
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }

  Future<void> deletePayment(
      {required String accessToken, required String id}) async {
    await _dio.delete(
      '/api/payments/$id',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }
}
