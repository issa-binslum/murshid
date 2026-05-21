class PurchaseOrderItem {
  final String id;
  final String itemId;
  final String itemName;
  final String unitName;
  final double qty;
  final double unitPrice;
  final double total;

  const PurchaseOrderItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.unitName,
    required this.qty,
    required this.unitPrice,
    required this.total,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> j) {
    final item = j['item'] as Map<String, dynamic>;
    return PurchaseOrderItem(
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

class PurchaseOrder {
  final String id;
  final String supplierId;
  final String supplierName;
  final DateTime date;
  final String? description;
  final double total;
  final bool isCancelled;
  final List<PurchaseOrderItem> items;

  const PurchaseOrder({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.date,
    this.description,
    required this.total,
    required this.isCancelled,
    required this.items,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> j) {
    final supplier = j['supplier'] as Map<String, dynamic>;
    return PurchaseOrder(
      id: j['id'] as String,
      supplierId: j['supplierId'] as String,
      supplierName: supplier['name'] as String,
      date: DateTime.parse(j['date'] as String),
      description: j['description'] as String?,
      total: double.parse(j['total'].toString()),
      isCancelled: j['cancelledAt'] != null,
      items: (j['items'] as List)
          .map((i) => PurchaseOrderItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PurchaseInvoiceItem {
  final String id;
  final String itemId;
  final String itemName;
  final String unitName;
  final double qty;
  final double unitPrice;
  final double total;

  const PurchaseInvoiceItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.unitName,
    required this.qty,
    required this.unitPrice,
    required this.total,
  });

  factory PurchaseInvoiceItem.fromJson(Map<String, dynamic> j) {
    final item = j['item'] as Map<String, dynamic>;
    return PurchaseInvoiceItem(
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

class PurchaseInvoice {
  final String id;
  final String supplierId;
  final String supplierName;
  final DateTime date;
  final String? description;
  final double total;
  final String status;
  final double paidAmount;
  final List<PurchaseInvoiceItem> items;

  const PurchaseInvoice({
    required this.id,
    required this.supplierId,
    required this.supplierName,
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

  factory PurchaseInvoice.fromJson(Map<String, dynamic> j) {
    final supplier = j['supplier'] as Map<String, dynamic>;
    return PurchaseInvoice(
      id: j['id'] as String,
      supplierId: j['supplierId'] as String,
      supplierName: supplier['name'] as String,
      date: DateTime.parse(j['date'] as String),
      description: j['description'] as String?,
      total: double.parse(j['total'].toString()),
      status: j['status'] as String,
      paidAmount: double.parse((j['paidAmount'] ?? 0).toString()),
      items: (j['items'] as List)
          .map((i) => PurchaseInvoiceItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}
