import 'package:flutter_test/flutter_test.dart';
import 'package:linkedin_ai_automation/models/post_model.dart';
import 'package:linkedin_ai_automation/models/user_model.dart';
import 'package:linkedin_ai_automation/models/license_model.dart';
import 'package:linkedin_ai_automation/services/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PostModel Unit Tests', () {
    test('JSON serialization and deserialization', () {
      final now = DateTime.now();
      final post = PostModel(
        id: 'post-101',
        clientId: 'client-101',
        title: 'Zero Trust Security',
        topic: 'Cloud security',
        body: 'Zero trust architecture requires continuous verification.',
        status: 'pending_approval',
        approvalRequired: true,
        scheduledAt: now.add(const Duration(hours: 4)),
        createdAt: now,
      );

      final json = post.toJson();
      expect(json['id'], 'post-101');
      expect(json['topic'], 'Cloud security');
      expect(json['approval_required'], true);

      final fromJson = PostModel.fromJson(json);
      expect(fromJson.id, post.id);
      expect(fromJson.body, post.body);
      expect(fromJson.status, post.status);
    });

    test('SQLite map serialization and deserialization', () {
      final post = PostModel(
        id: 'post-102',
        body: 'SOC operations and alert triage.',
        status: 'draft',
        approvalRequired: false,
        createdAt: DateTime.now(),
        isSynced: false,
      );

      final sqliteMap = post.toSqliteMap();
      expect(sqliteMap['id'], 'post-102');
      expect(sqliteMap['approval_required'], 0);
      expect(sqliteMap['is_synced'], 0);

      final fromSqlite = PostModel.fromSqliteMap(sqliteMap);
      expect(fromSqlite.id, 'post-102');
      expect(fromSqlite.approvalRequired, false);
      expect(fromSqlite.isSynced, false);
    });

    test('copyWith creates modified clone', () {
      final post = PostModel(
        id: 'post-103',
        body: 'Original content',
        status: 'draft',
        approvalRequired: true,
        createdAt: DateTime.now(),
      );

      final approved = post.copyWith(status: 'scheduled');
      expect(approved.id, post.id);
      expect(approved.status, 'scheduled');
      expect(approved.body, 'Original content');
    });
  });

  group('UserModel Unit Tests', () {
    test('parses customer profile correctly', () {
      final json = {
        'id': 'user-1',
        'email': 'customer@example.com',
        'role': 'user',
        'admin_role': null,
        'has_active_license': true,
        'license_plan': 'pro',
        'license_cycle': 'yearly',
        'linkedin_connected': true,
        'linkedin_profile_name': 'Alice Cyber',
        'created_at': DateTime.now().toIso8601String(),
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 'user-1');
      expect(user.isAdmin, false);
      expect(user.isSuperAdmin, false);
      expect(user.hasActiveLicense, true);
      expect(user.linkedinConnected, true);
    });

    test('parses Super Admin role correctly', () {
      final json = {
        'id': 'user-super',
        'email': 'superadmin@linkpilot.io',
        'role': 'user',
        'admin_role': 'super_admin',
        'has_active_license': true,
        'linkedin_connected': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final user = UserModel.fromJson(json);
      expect(user.isAdmin, true);
      expect(user.isSuperAdmin, true);
    });

    test('parses Staff Admin role correctly', () {
      final json = {
        'id': 'user-staff',
        'email': 'staff@linkpilot.io',
        'role': 'user',
        'admin_role': 'staff',
        'has_active_license': true,
        'linkedin_connected': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final user = UserModel.fromJson(json);
      expect(user.isAdmin, true);
      expect(user.isSuperAdmin, false);
    });
  });

  group('LicenseModel Unit Tests', () {
    test('parses license data correctly', () {
      final json = {
        'id': 'lic-1',
        'plan': 'business',
        'billing_cycle': 'lifetime',
        'active': true,
        'assigned': false,
        'user_id': null,
        'expires_at': null,
        'created_at': DateTime.now().toIso8601String(),
        'max_devices': 1,
      };

      final lic = LicenseModel.fromJson(json);
      expect(lic.id, 'lic-1');
      expect(lic.plan, 'business');
      expect(lic.billingCycle, 'lifetime');
      expect(lic.active, true);
      expect(lic.expiresAt, null);
    });
  });

  group('ApiClient Configuration Tests', () {
    test('default base URL is set', () {
      final client = ApiClient(baseUrl: 'http://127.0.0.1:8000');
      expect(client.baseUrl, 'http://127.0.0.1:8000');
    });

    test('ApiException formatting', () {
      final exc = ApiException(403, 'An active LinkPilot license is required');
      expect(exc.statusCode, 403);
      expect(exc.message, contains('active LinkPilot license is required'));
      expect(exc.toString(), 'ApiException(403): An active LinkPilot license is required');
    });
  });
}
