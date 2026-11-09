class UserModel {
  final String id;
  final String email;
  final String role;
  final String? adminRole;
  final bool hasActiveLicense;
  final String? licensePlan;
  final String? licenseCycle;
  final DateTime? licenseExpiresAt;
  final int? daysRemaining;
  final bool linkedinConnected;
  final String? linkedinProfileName;
  final bool isApproved;
  final DateTime? approvedAt;
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
    this.daysRemaining,
    required this.linkedinConnected,
    this.linkedinProfileName,
    this.isApproved = true,
    this.approvedAt,
    required this.createdAt,
  });

  bool get isAdmin => adminRole == 'super_admin' || adminRole == 'staff';
  bool get isSuperAdmin => adminRole == 'super_admin';

  factory UserModel.projectUser({
    String email = 'resanul@gmail.com',
    bool linkedinConnected = false,
    String? linkedinProfileName,
    int? daysRemaining = 30,
    bool isApproved = true,
  }) {
    return UserModel(
      id: 'project-owner',
      email: email,
      role: 'super_admin',
      adminRole: 'super_admin',
      hasActiveLicense: true,
      licensePlan: 'Enterprise Plan',
      licenseCycle: '30_days',
      daysRemaining: daysRemaining,
      linkedinConnected: linkedinConnected,
      linkedinProfileName: linkedinProfileName,
      isApproved: isApproved,
      approvedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  factory UserModel.adminUser({
    String email = 'admin@linkpilot.ai',
  }) {
    return UserModel(
      id: 'admin-master',
      email: email,
      role: 'super_admin',
      adminRole: 'super_admin',
      hasActiveLicense: true,
      licensePlan: 'Enterprise',
      licenseCycle: 'lifetime',
      daysRemaining: null,
      linkedinConnected: false,
      isApproved: true,
      approvedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  factory UserModel.customerUser({
    String email = 'customer@linkpilot.ai',
    bool hasLicense = false,
    bool isApproved = true,
  }) {
    return UserModel(
      id: 'customer-client',
      email: email,
      role: 'user',
      adminRole: null,
      hasActiveLicense: hasLicense,
      licensePlan: hasLicense ? 'Standard' : null,
      licenseCycle: hasLicense ? '30_days' : null,
      daysRemaining: hasLicense ? 30 : null,
      linkedinConnected: false,
      isApproved: isApproved,
      approvedAt: isApproved ? DateTime.now() : null,
      createdAt: DateTime.now(),
    );
  }

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
      daysRemaining: json['days_remaining'] as int?,
      linkedinConnected: (json['linkedin_connected'] as bool?) ?? false,
      linkedinProfileName: json['linkedin_profile_name'] as String?,
      isApproved: (json['is_approved'] as bool?) ?? true,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
