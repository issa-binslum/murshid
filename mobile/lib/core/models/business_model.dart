class BusinessModel {
  final String id;
  final String name;
  final String currency;
  final bool isOwner;

  const BusinessModel({
    required this.id,
    required this.name,
    required this.currency,
    this.isOwner = false,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) => BusinessModel(
        id: json['id'] as String,
        name: json['name'] as String,
        currency: json['currency'] as String,
        isOwner: json['isOwner'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'currency': currency,
        'isOwner': isOwner,
      };
}
