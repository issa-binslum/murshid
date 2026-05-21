class SalesOrderItem {
  final String id;
  final String itemId;
  final String itemName;
  final String unitName;
  final double qty;
  final double unitPrice;
  final double total;

  const SalesOrderItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.unitName,
    required this.qty,
    required this.unitPrice,
    required this.total,
  });

  factory SalesOrderItem.fromJson(Map<String, dynamic> j) {
    final item = j['item'] as Map<String, dynamic>;
    return SalesOrderItem(
      id: j['id'] as String,
      itemId: j['itemId'] as String,
      itemName: item['itemName'] as String,
      unitName: item['unitName'] as String,
      qty: double.parse(j['qty'].toString()),
      unitPrice: double.parse(j['unitPrice'].toString()),
      total: double.parse(j['total'].toString()),
    );
  }
}

class SalesOrder {
  final String id;
  final String customerId;
  final String customerName;
  final DateTime date;
  final String? address;
  final String? description;
  final double total;
  final bool isCancelled;
  final List<SalesOrderItem> items;

  const SalesOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.date,
    this.address,
    this.description,
    required this.total,
    required this.isCancelled,
    required this.items,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> j) {
    final customer = j['customer'] as Map<String, dynamic>;
    return SalesOrder(
      id: j['id'] as String,
      customerId: j['customerId'] as String,
      customerName: customer['name'] as String,
      date: DateTime.parse(j['date'] as String),
      address: j['address'] as String?,
      description: j['description'] as String?,
      total: double.parse(j['total'].toString()),
      isCancelled: j['cancelledAt'] != null,
      items: (j['items'] as List)
          .map((i) => SalesOrderItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SalesInvoiceItem {
  final String id;
  final String itemId;
  final String itemName;
  final String unitName;
  final double qty;
  final double unitPrice;
  final double total;

  const SalesInvoiceItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.unitName,
    required this.qty,
    required this.unitPrice,
    required this.total,
  });

  factory SalesInvoiceItem.fromJson(Map<String, dynamic> j) {
    final item = j['item'] as Map<String, dynamic>;
    return SalesInvoiceItem(
      id: j['id'] as String,
      itemId: j['itemId'] as String,
      itemName: item['itemName'] as String,
      unitName: item['unitName'] as String,
      qty: double.parse(j['qty'].toString()),
      unitPrice: double.parse(j['unitPrice'].toString()),
      total: double.parse(j['total'].toString()),
    );
  }
}

class SalesInvoice {
  final String id;
  final String customerId;
  final String customerName;
  final DateTime date;
  final String? description;
  final double total;
  final String status;
  final double paidAmount;
  final List<SalesInvoiceItem> items;

  const SalesInvoice({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.date,
    this.description,
    required this.total,
    required this.status,
    required this.paidAmount,
    required this.items,
  });

  double get balance => total - paidAmount;
  bool get isCancelled => status == 'CANCELLED';
  bool get isPaid => status == 'PAID';

  factory SalesInvoice.fromJson(Map<String, dynamic> j) {
    final customer = j['customer'] as Map<String, dynamic>;
    return SalesInvoice(
      id: j['id'] as String,
      customerId: j['customerId'] as String,
      customerName: customer['name'] as String,
      date: DateTime.parse(j['date'] as String),
      description: j['description'] as String?,
      total: double.parse(j['total'].toString()),
      status: j['status'] as String,
      paidAmount: double.parse((j['paidAmount'] ?? 0).toString()),
      items: (j['items'] as List)
          .map((i) => SalesInvoiceItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}
