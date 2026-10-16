import '../../../core/branding/branding.dart';
import '../../../core/i18n/i18n.dart';

enum UserRole {
  admin('Kurum Müdürü'),
  coach('Koç'),
  student('Öğrenci'),
  parent('Veli');

  const UserRole(this.trLabel);
  final String trLabel;

  String get label => tr(trLabel);

  static UserRole fromName(String name) =>
      UserRole.values.firstWhere((r) => r.name == name);
}

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    this.orgId,
    this.avatar,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    fullName: json['full_name'] as String,
    role: UserRole.fromName(json['role'] as String),
    orgId: json['org_id'] as String?,
    avatar: json['avatar'] is Map
        ? Map<String, dynamic>.from(json['avatar'] as Map)
        : null,
  );

  final String id;
  final String fullName;
  final UserRole role;
  final String? orgId;

  /// Öğrenci avatarı (ham JSON, ör. {"hair": 3, "skin": 7}); bkz. AvatarConfig.
  final Map<String, dynamic>? avatar;

  String get firstName => fullName.split(' ').first;
}

/// `check_invite` RPC sonucu.
class InviteInfo {
  const InviteInfo({required this.role, required this.orgName, this.tenant});

  factory InviteInfo.fromJson(Map<String, dynamic> json) => InviteInfo(
    role: UserRole.fromName(json['role'] as String),
    orgName: json['org_name'] as String,
    tenant: json['tenant'] is Map
        ? Branding.fromJson(Map<String, dynamic>.from(json['tenant'] as Map))
        : null,
  );

  final UserRole role;
  final String orgName;

  /// Davetin ait olduğu dershanenin markası.
  final Branding? tenant;
}
