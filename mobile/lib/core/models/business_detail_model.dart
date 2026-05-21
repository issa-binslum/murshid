class BusinessDetail {
  final String id;
  final String name;
  final String? type;
  final String? address;
  final String? phone;
  final String? email;
  final String currency;
  final bool isOwner;
  final String role;
  final DateTime createdAt;

  const BusinessDetail({
    required this.id,
    required this.name,
    this.type,
    this.address,
    this.phone,
    this.email,
    required this.currency,
    required this.isOwner,
    required this.role,
    required this.createdAt,
  });

  factory BusinessDetail.fromJson(Map<String, dynamic> json) => BusinessDetail(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        currency: json['currency'] as String,
        isOwner: json['isOwner'] as bool? ?? false,
        role: json['role'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  BusinessDetail copyWith({
    String? name,
    String? type,
    String? address,
    String? phone,
    String? email,
    String? currency,
  }) =>
      BusinessDetail(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        currency: currency ?? this.currency,
        isOwner: isOwner,
        role: role,
        createdAt: createdAt,
      );
}
