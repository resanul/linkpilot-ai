import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'secure_storage_service.dart';

class GitHubCloudService {
  static final GitHubCloudService instance = GitHubCloudService._internal();
  GitHubCloudService._internal();

  static const String rawBaseUrl =
      'https://raw.githubusercontent.com/resanul/linkpilot-ai/main/cloud';

  static const List<String> adminEmails = [
    'resanul@gmail.com',
    'admin@linkpilot.ai',
    'superadmin@linkpilot.io',
  ];

  List<Map<String, dynamic>> _cachedUsers = [];
  List<Map<String, dynamic>> _cachedLicenses = [];
  final Map<String, Map<String, dynamic>> _localPendingUsers = {};

  bool isAdminEmail(String email) {
    return adminEmails.contains(email.trim().toLowerCase());
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      final res = await http
          .get(Uri.parse('$rawBaseUrl/users.json'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body) as List<dynamic>;
        _cachedUsers = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {
      // Fallback to local cache if network is unavailable
    }

    // Merge in any locally registered users
    final Set<String> existingEmails =
        _cachedUsers.map((u) => (u['email'] as String? ?? '').toLowerCase()).toSet();

    for (final entry in _localPendingUsers.values) {
      final email = (entry['email'] as String? ?? '').toLowerCase();
      if (!existingEmails.contains(email)) {
        _cachedUsers.add(entry);
      }
    }

    return _cachedUsers;
  }

  Future<List<Map<String, dynamic>>> fetchLicenses() async {
    try {
      final res = await http
          .get(Uri.parse('$rawBaseUrl/licenses.json'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body) as List<dynamic>;
        _cachedLicenses = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {
      // Fallback to local cache
    }
    return _cachedLicenses;
  }

  Future<UserModel> registerOrLoginGoogleUser(String rawEmail) async {
    final email = rawEmail.trim().toLowerCase();
    await fetchUsers();

    if (isAdminEmail(email)) {
      final admin = UserModel.projectUser(
        email: email,
        linkedinConnected: false,
        daysRemaining: null,
        isApproved: true,
      );
      await SecureStorageService.instance.saveUserEmail(email);
      return admin;
    }

    // Check if user already exists in cloud or local cache
    final existingIndex = _cachedUsers.indexWhere(
      (u) => (u['email'] as String? ?? '').toLowerCase() == email,
    );

    if (existingIndex != -1) {
      final data = _cachedUsers[existingIndex];
      final user = UserModel.fromJson(data);
      await SecureStorageService.instance.saveUserEmail(email);
      return user;
    }

    // New Google Registration -> Starts as pending approval
    final newUserMap = <String, dynamic>{
      'id': 'u-${DateTime.now().millisecondsSinceEpoch}',
      'email': email,
      'role': 'user',
      'admin_role': null,
      'is_approved': false,
      'approved_at': null,
      'has_active_license': false,
      'license_plan': null,
      'license_cycle': null,
      'license_expires_at': null,
      'days_remaining': null,
      'linkedin_connected': false,
      'linkedin_profile_name': null,
      'created_at': DateTime.now().toIso8601String(),
    };

    _localPendingUsers[email] = newUserMap;
    _cachedUsers.add(newUserMap);

    await SecureStorageService.instance.saveUserEmail(email);
    return UserModel.fromJson(newUserMap);
  }

  Future<UserModel> getUserProfile(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (isAdminEmail(cleanEmail)) {
      return UserModel.projectUser(
        email: cleanEmail,
        linkedinConnected: false,
        daysRemaining: null,
        isApproved: true,
      );
    }

    await fetchUsers();
    final match = _cachedUsers.firstWhere(
      (u) => (u['email'] as String? ?? '').toLowerCase() == cleanEmail,
      orElse: () => {
        'id': 'u-${DateTime.now().millisecondsSinceEpoch}',
        'email': cleanEmail,
        'role': 'user',
        'is_approved': false,
        'has_active_license': false,
        'created_at': DateTime.now().toIso8601String(),
      },
    );

    return UserModel.fromJson(match);
  }

  Future<Map<String, dynamic>> activateLicense(String email, String licenseKey) async {
    final cleanEmail = email.trim().toLowerCase();
    final key = licenseKey.trim().toUpperCase();

    await fetchLicenses();
    final lic = _cachedLicenses.firstWhere(
      (l) => (l['key'] as String? ?? '').toUpperCase() == key && (l['is_active'] as bool? ?? true),
      orElse: () => throw Exception('License key not found or expired in GitHub registry.'),
    );

    final plan = lic['plan'] as String? ?? 'Standard';
    final billingCycle = lic['billing_cycle'] as String? ?? '30_days';
    final durationDays = lic['duration_days'] as int? ?? 30;

    // Update user in cache
    final uIdx = _cachedUsers.indexWhere(
      (u) => (u['email'] as String? ?? '').toLowerCase() == cleanEmail,
    );

    if (uIdx != -1) {
      _cachedUsers[uIdx]['has_active_license'] = true;
      _cachedUsers[uIdx]['license_plan'] = plan;
      _cachedUsers[uIdx]['license_cycle'] = billingCycle;
      _cachedUsers[uIdx]['days_remaining'] = durationDays;
      _cachedUsers[uIdx]['license_expires_at'] =
          DateTime.now().add(Duration(days: durationDays)).toIso8601String();
    }

    return {
      'status': 'activated',
      'key': key,
      'plan': plan,
      'billing_cycle': billingCycle,
      'days_remaining': durationDays,
    };
  }

  Future<void> adminApproveUser(String userId) async {
    final idx = _cachedUsers.indexWhere((u) => u['id'] == userId);
    if (idx != -1) {
      _cachedUsers[idx]['is_approved'] = true;
      _cachedUsers[idx]['approved_at'] = DateTime.now().toIso8601String();
      final email = _cachedUsers[idx]['email'] as String?;
      if (email != null && _localPendingUsers.containsKey(email)) {
        _localPendingUsers[email]!['is_approved'] = true;
        _localPendingUsers[email]!['approved_at'] = DateTime.now().toIso8601String();
      }
    }
  }

  Future<void> adminRejectUser(String userId) async {
    final idx = _cachedUsers.indexWhere((u) => u['id'] == userId);
    if (idx != -1) {
      _cachedUsers[idx]['is_approved'] = false;
      final email = _cachedUsers[idx]['email'] as String?;
      if (email != null && _localPendingUsers.containsKey(email)) {
        _localPendingUsers[email]!['is_approved'] = false;
      }
    }
  }
}
