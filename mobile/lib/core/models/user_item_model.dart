class UserItem {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String username;
  final String status;
  final bool isOwner;
  final List<String> permissions;

  const UserItem({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.username,
    required this.status,
    required this.isOwner,
    this.permissions = const [],
  });

  bool get isActive => status == 'ACTIVE';
  bool hasPermission(String key) => permissions.contains(key);

  factory UserItem.fromJson(Map<String, dynamic> json) => UserItem(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        username: json['username'] as String,
        status: json['status'] as String,
        isOwner: json['isOwner'] as bool,
        permissions: (json['permissions'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      );

  UserItem copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? username,
    String? status,
    bool? isOwner,
    List<String>? permissions,
  }) =>
      UserItem(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        username: username ?? this.username,
        status: status ?? this.status,
        isOwner: isOwner ?? this.isOwner,
        permissions: permissions ?? this.permissions,
      );
}

class PermissionItem {
  final String key;
  final String name;

  const PermissionItem({required this.key, required this.name});

  factory PermissionItem.fromJson(Map<String, dynamic> json) => PermissionItem(
        key: json['key'] as String,
        name: json['name'] as String,
      );
}
