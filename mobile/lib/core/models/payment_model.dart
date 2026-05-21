class Payment {
  final String id;
  final DateTime date;
  final String? payee;
  final String? supplierId;
  final String accountId;
  final double amount;
  final String? description;

  const Payment({
    required this.id,
    required this.date,
    this.payee,
    this.supplierId,
    required this.accountId,
    required this.amount,
    this.description,
  });

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        payee: j['payee'] as String?,
        supplierId: j['supplierId'] as String?,
        accountId: j['accountId'] as String,
        amount: double.parse(j['amount'].toString()),
        description: j['description'] as String?,
      );
}
