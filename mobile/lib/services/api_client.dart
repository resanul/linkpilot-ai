import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/license_model.dart';
import 'secure_storage_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  final SecureStorageService _storage = SecureStorageService.instance;
  String _baseUrl = defaultBaseUrl;

  ApiClient({String? baseUrl}) {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      _baseUrl = baseUrl;
    }
  }

  String get baseUrl => _baseUrl;

  Future<String> getBaseUrl() async {
    final customUrl = await _storage.getBaseUrl();
    if (customUrl != null && customUrl.isNotEmpty) {
      _baseUrl = customUrl;
    }
    return _baseUrl;
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
    _storage.saveBaseUrl(url);
  }

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getAuthToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse(_baseUrl);
    return base.replace(
      path: '${base.path}$cleanPath'.replaceAll('//', '/'),
      queryParameters: queryParameters,
    );
  }

  Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    String message = 'Server error (${response.statusCode})';
    try {
      final errJson = jsonDecode(utf8.decode(response.bodyBytes));
      if (errJson is Map && errJson.containsKey('detail')) {
        message = errJson['detail'].toString();
      }
    } catch (_) {}
    throw ApiException(response.statusCode, message);
  }

  Future<Map<String, dynamic>> getHealth() async {
    final uri = _uri('/health');
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  Future<UserModel> getUserProfile() async {
    final uri = _uri('/user/profile');
    final headers = await _headers();
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    final data = await _handleResponse(res);
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> activateLicense(String licenseKey) async {
    final uri = _uri('/license/activate');
    final headers = await _headers();
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'license_key': licenseKey.trim()}),
    ).timeout(const Duration(seconds: 15));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLicenseStatus() async {
    final uri = _uri('/license/status');
    final headers = await _headers();
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLinkedInStatus() async {
    final uri = _uri('/linkedin/status');
    final headers = await _headers();
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  Future<String> getLinkedInConnectUrl() async {
    final uri = _uri('/linkedin/connect');
    final headers = await _headers();
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    final data = await _handleResponse(res) as Map<String, dynamic>;
    return data['authorization_url'] as String;
  }

  Future<Map<String, dynamic>> disconnectLinkedIn() async {
    final uri = _uri('/linkedin/disconnect');
    final headers = await _headers();
    final res = await http.post(uri, headers: headers).timeout(const Duration(seconds: 15));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  Future<List<PostModel>> getPosts({String? status}) async {
    final query = status != null ? {'status': status} : null;
    final uri = _uri('/posts', query);
    final headers = await _headers();
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
    final list = await _handleResponse(res) as List<dynamic>;
    return list.map((e) => PostModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PostModel> createPost({
    required String body,
    String? title,
    String? topic,
    bool approvalRequired = true,
    DateTime? scheduledAt,
    String? clientId,
  }) async {
    final uri = _uri('/posts');
    final headers = await _headers();
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'body': body,
        'title': title,
        'topic': topic,
        'approval_required': approvalRequired,
        'scheduled_at': scheduledAt?.toIso8601String(),
        'client_id': clientId,
      }),
    ).timeout(const Duration(seconds: 20));
    final data = await _handleResponse(res);
    return PostModel.fromJson(data as Map<String, dynamic>);
  }

  Future<PostModel> updatePost(String postId, {
    String? body,
    String? title,
    String? topic,
    bool? approvalRequired,
    DateTime? scheduledAt,
  }) async {
    final uri = _uri('/posts/$postId');
    final headers = await _headers();
    final res = await http.put(
      uri,
      headers: headers,
      body: jsonEncode({
        if (body != null) 'body': body,
        if (title != null) 'title': title,
        if (topic != null) 'topic': topic,
        if (approvalRequired != null) 'approval_required': approvalRequired,
        if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 15));
    final data = await _handleResponse(res);
    return PostModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deletePost(String postId) async {
    final uri = _uri('/posts/$postId');
    final headers = await _headers();
    final res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
    await _handleResponse(res);
  }

  Future<Map<String, dynamic>> approvePost(String postId) async {
    final uri = _uri('/posts/$postId/approve');
    final headers = await _headers();
    final res = await http.post(uri, headers: headers).timeout(const Duration(seconds: 15));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectPost(String postId) async {
    final uri = _uri('/posts/$postId/reject');
    final headers = await _headers();
    final res = await http.post(uri, headers: headers).timeout(const Duration(seconds: 15));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  Future<List<PostModel>> syncPosts(List<PostModel> offlinePosts) async {
    final uri = _uri('/posts/sync');
    final headers = await _headers();
    final payload = {
      'posts': offlinePosts.map((p) => {
        'client_id': p.clientId ?? p.id,
        'title': p.title,
        'topic': p.topic,
        'body': p.body,
        'status': p.status,
        'approval_required': p.approvalRequired,
        'scheduled_at': p.scheduledAt?.toIso8601String(),
        'created_at': p.createdAt.toIso8601String(),
        'updated_at': p.updatedAt?.toIso8601String(),
      }).toList()
    };
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));
    final data = await _handleResponse(res) as Map<String, dynamic>;
    final list = data['synced_posts'] as List<dynamic>;
    return list.map((e) => PostModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> generateAIPost(String topic) async {
    final uri = _uri('/ai/generate');
    final headers = await _headers();
    final customApiKey = await _storage.getGeminiApiKey();
    final Map<String, dynamic> body = {'topic': topic};
    if (customApiKey != null && customApiKey.isNotEmpty) {
      body['gemini_api_key'] = customApiKey;
    }
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 45));
    final data = await _handleResponse(res) as Map<String, dynamic>;
    return data['content'] as String;
  }

  Future<String> regenerateAIPost(String originalBody, String topic, [String? instructions]) async {
    final uri = _uri('/ai/regenerate');
    final headers = await _headers();
    final customApiKey = await _storage.getGeminiApiKey();
    final Map<String, dynamic> body = {
      'original_body': originalBody,
      'topic': topic,
      'instructions': instructions,
    };
    if (customApiKey != null && customApiKey.isNotEmpty) {
      body['gemini_api_key'] = customApiKey;
    }
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 45));
    final data = await _handleResponse(res) as Map<String, dynamic>;
    return data['content'] as String;
  }

  Future<Map<String, dynamic>> connectLinkedInManual(String accessToken) async {
    final uri = _uri('/linkedin/connect-manual');
    final headers = await _headers();
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'access_token': accessToken}),
    ).timeout(const Duration(seconds: 25));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  // --- Admin API ---

  Future<Map<String, dynamic>> getAdminOverview() async {
    final uri = _uri('/admin/overview');
    final headers = await _headers();
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  Future<List<LicenseModel>> getAdminLicenses() async {
    final uri = _uri('/admin/licenses');
    final headers = await _headers();
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
    final list = await _handleResponse(res) as List<dynamic>;
    return list.map((e) => LicenseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> createAdminLicense(String plan, String billingCycle) async {
    final uri = _uri('/admin/licenses', {'plan': plan, 'billing_cycle': billingCycle});
    final headers = await _headers();
    final res = await http.post(uri, headers: headers).timeout(const Duration(seconds: 15));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> revokeAdminLicense(String licenseId) async {
    final uri = _uri('/admin/licenses/$licenseId/revoke');
    final headers = await _headers();
    final res = await http.post(uri, headers: headers).timeout(const Duration(seconds: 15));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAdminCustomers() async {
    final uri = _uri('/admin/customers');
    final headers = await _headers();
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
    final list = await _handleResponse(res) as List<dynamic>;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getAdminStaff() async {
    final uri = _uri('/admin/staff');
    final headers = await _headers();
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    final list = await _handleResponse(res) as List<dynamic>;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> addAdminStaff(String email) async {
    final uri = _uri('/admin/staff');
    final headers = await _headers();
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'email': email.trim().toLowerCase()}),
    ).timeout(const Duration(seconds: 15));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> revokeAdminStaff(String staffId) async {
    final uri = _uri('/admin/staff/$staffId/revoke');
    final headers = await _headers();
    final res = await http.post(uri, headers: headers).timeout(const Duration(seconds: 15));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAdminAuditLogs() async {
    final uri = _uri('/admin/audit-logs');
    final headers = await _headers();
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
    final list = await _handleResponse(res) as List<dynamic>;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }
}
