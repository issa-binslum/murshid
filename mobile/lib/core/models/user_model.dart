class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String username;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.username,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        username: json['username'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'username': username,
      };
}
