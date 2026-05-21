class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? billingAddress;
  final String? deliveryAddress;
  final double creditLimit;
  final double balance;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.billingAddress,
    this.deliveryAddress,
    required this.creditLimit,
    required this.balance,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        billingAddress: j['billingAddress'] as String?,
        deliveryAddress: j['deliveryAddress'] as String?,
        creditLimit: double.parse(j['creditLimit'].toString()),
        balance: double.parse(j['balance'].toString()),
      );
}
