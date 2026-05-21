class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final double creditLimit;
  final double balance;

  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    required this.creditLimit,
    required this.balance,
  });

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        address: j['address'] as String?,
        creditLimit: double.parse(j['creditLimit'].toString()),
        balance: double.parse(j['balance'].toString()),
      );
}
