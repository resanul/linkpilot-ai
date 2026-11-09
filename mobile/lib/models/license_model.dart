class LicenseModel {
  final String id;
  final String plan;
  final String billingCycle;
  final bool active;
  final bool assigned;
  final String? userId;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime? activatedAt;
  final int maxDevices;

  LicenseModel({
    required this.id,
    required this.plan,
    required this.billingCycle,
    required this.active,
    required this.assigned,
    this.userId,
    this.expiresAt,
    required this.createdAt,
    this.activatedAt,
    this.maxDevices = 1,
  });

  factory LicenseModel.fromJson(Map<String, dynamic> json) {
    return LicenseModel(
      id: json['id'] as String,
      plan: (json['plan'] as String?) ?? 'standard',
      billingCycle: (json['billing_cycle'] as String?) ?? 'monthly',
      active: (json['active'] as bool?) ?? true,
      assigned: (json['assigned'] as bool?) ?? false,
      userId: json['user_id'] as String?,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      activatedAt: json['activated_at'] != null ? DateTime.tryParse(json['activated_at'] as String) : null,
      maxDevices: (json['max_devices'] as int?) ?? 1,
    );
  }
}
