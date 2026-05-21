class InventoryItem {
  final String id;
  final String itemCode;
  final String itemName;
  final String unitName;
  final double quantity;
  final double lowStockLevel;
  final double purchasePrice;
  final double salesPrice;
  final String? description;

  const InventoryItem({
    required this.id,
    required this.itemCode,
    required this.itemName,
    required this.unitName,
    required this.quantity,
    required this.lowStockLevel,
    required this.purchasePrice,
    required this.salesPrice,
    this.description,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        id: j['id'] as String,
        itemCode: j['itemCode'] as String,
        itemName: j['itemName'] as String,
        unitName: j['unitName'] as String,
        quantity: double.parse(j['quantity'].toString()),
        lowStockLevel: double.parse(j['lowStockLevel'].toString()),
        purchasePrice: double.parse(j['purchasePrice'].toString()),
        salesPrice: double.parse(j['salesPrice'].toString()),
        description: j['description'] as String?,
      );

  bool get isLowStock => quantity <= lowStockLevel && lowStockLevel > 0;
}
