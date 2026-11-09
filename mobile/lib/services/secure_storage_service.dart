import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._internal();
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyAuthToken = 'auth_token';
  static const String _keyBaseUrl = 'api_base_url';
  static const String _keyUserEmail = 'user_email';
  static const String _keyGeminiApiKey = 'gemini_api_key';
  static const String _keyLinkedInToken = 'linkedin_token';
  static const String _keyPreferredTopics = 'preferred_topics';

  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _keyAuthToken, value: token);
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: _keyAuthToken);
  }

  Future<void> deleteAuthToken() async {
    await _storage.delete(key: _keyAuthToken);
  }

  Future<void> saveBaseUrl(String url) async {
    await _storage.write(key: _keyBaseUrl, value: url);
  }

  Future<String?> getBaseUrl() async {
    return await _storage.read(key: _keyBaseUrl);
  }

  Future<void> saveUserEmail(String email) async {
    await _storage.write(key: _keyUserEmail, value: email);
  }

  Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  Future<void> saveGeminiApiKey(String key) async {
    await _storage.write(key: _keyGeminiApiKey, value: key);
  }

  Future<String?> getGeminiApiKey() async {
    return await _storage.read(key: _keyGeminiApiKey);
  }

  Future<void> saveLinkedInToken(String token) async {
    await _storage.write(key: _keyLinkedInToken, value: token);
  }

  Future<String?> getLinkedInToken() async {
    return await _storage.read(key: _keyLinkedInToken);
  }

  Future<void> savePreferredTopics(List<String> topics) async {
    await _storage.write(key: _keyPreferredTopics, value: topics.join('|||'));
  }

  Future<List<String>> getPreferredTopics() async {
    final raw = await _storage.read(key: _keyPreferredTopics);
    if (raw == null || raw.trim().isEmpty) return [];
    return raw.split('|||').where((s) => s.isNotEmpty).toList();
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
