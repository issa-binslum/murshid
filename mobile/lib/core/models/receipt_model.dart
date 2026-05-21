class ReceiptItem {
  final String id;
  final String itemId;
  final String itemName;
  final double qty;
  final double unitPrice;
  final double total;

  const ReceiptItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.unitPrice,
    required this.total,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> j) => ReceiptItem(
        id: j['id'] as String,
        itemId: j['itemId'] as String,
        itemName: (j['item'] as Map<String, dynamic>?)?['itemName'] as String? ?? '',
        qty: double.parse(j['qty'].toString()),
        unitPrice: double.parse(j['unitPrice'].toString()),
        total: double.parse(j['total'].toString()),
      );
}

class Receipt {
  final String id;
  final DateTime date;
  final String? paidBy;
  final String? customerId;
  final String accountId;
  final double amount;
  final String? description;
  final List<ReceiptItem> items;

  const Receipt({
    required this.id,
    required this.date,
    this.paidBy,
    this.customerId,
    required this.accountId,
    required this.amount,
    this.description,
    this.items = const [],
  });

  factory Receipt.fromJson(Map<String, dynamic> j) => Receipt(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        paidBy: j['paidBy'] as String?,
        customerId: j['customerId'] as String?,
        accountId: j['accountId'] as String,
        amount: double.parse(j['amount'].toString()),
        description: j['description'] as String?,
        items: (j['items'] as List<dynamic>? ?? [])
            .map((i) => ReceiptItem.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}
