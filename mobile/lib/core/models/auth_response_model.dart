import 'business_model.dart';
import 'user_model.dart';

/// Shape returned by POST /api/auth/login (step 1)
class LoginResponse {
  final UserModel user;
  final String preAuthToken;
  final List<BusinessItem> businesses;

  const LoginResponse({
    required this.user,
    required this.preAuthToken,
    required this.businesses,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
        preAuthToken: json['preAuthToken'] as String,
        businesses: (json['businesses'] as List<dynamic>)
            .map((b) => BusinessItem.fromJson(b as Map<String, dynamic>))
            .toList(),
      );
}

/// One entry in the businesses list from login
class BusinessItem {
  final String businessId;
  final String businessName;
  final String roleId;
  final String roleName;
  final bool isOwner;
  final String currency;

  const BusinessItem({
    required this.businessId,
    required this.businessName,
    required this.roleId,
    required this.roleName,
    required this.isOwner,
    required this.currency,
  });

  factory BusinessItem.fromJson(Map<String, dynamic> json) => BusinessItem(
        businessId: json['businessId'] as String,
        businessName: json['businessName'] as String,
        roleId: json['roleId'] as String,
        roleName: json['roleName'] as String,
        isOwner: json['isOwner'] as bool? ?? false,
        currency: json['currency'] as String,
      );

  Map<String, dynamic> toJson() => {
        'businessId': businessId,
        'businessName': businessName,
        'roleId': roleId,
        'roleName': roleName,
        'isOwner': isOwner,
        'currency': currency,
      };

  BusinessModel toBusinessModel() => BusinessModel(
        id: businessId,
        name: businessName,
        currency: currency,
        isOwner: isOwner,
      );
}

/// Shape returned by POST /api/auth/switch-business (step 2)
class SwitchBusinessResult {
  final String accessToken;
  final BusinessModel business;
  final String roleId;
  final List<String> permissions;

  const SwitchBusinessResult({
    required this.accessToken,
    required this.business,
    required this.roleId,
    required this.permissions,
  });

  factory SwitchBusinessResult.fromJson(Map<String, dynamic> json) =>
      SwitchBusinessResult(
        accessToken: json['accessToken'] as String,
        business: BusinessModel.fromJson(
            json['business'] as Map<String, dynamic>),
        roleId: (json['role'] as Map<String, dynamic>)['id'] as String,
        permissions: (json['permissions'] as List<dynamic>)
            .map((p) => p as String)
            .toList(),
      );
}
