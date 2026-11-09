class UserModel {
  final String id;
  final String email;
  final String role;
  final String? adminRole;
  final bool hasActiveLicense;
  final String? licensePlan;
  final String? licenseCycle;
  final DateTime? licenseExpiresAt;
  final bool linkedinConnected;
  final String? linkedinProfileName;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.adminRole,
    required this.hasActiveLicense,
    this.licensePlan,
    this.licenseCycle,
    this.licenseExpiresAt,
    required this.linkedinConnected,
    this.linkedinProfileName,
    required this.createdAt,
  });

  bool get isAdmin => adminRole == 'super_admin' || adminRole == 'staff';
  bool get isSuperAdmin => adminRole == 'super_admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: (json['role'] as String?) ?? 'user',
      adminRole: json['admin_role'] as String?,
      hasActiveLicense: (json['has_active_license'] as bool?) ?? false,
      licensePlan: json['license_plan'] as String?,
      licenseCycle: json['license_cycle'] as String?,
      licenseExpiresAt: json['license_expires_at'] != null
          ? DateTime.tryParse(json['license_expires_at'] as String)
          : null,
      linkedinConnected: (json['linkedin_connected'] as bool?) ?? false,
      linkedinProfileName: json['linkedin_profile_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
