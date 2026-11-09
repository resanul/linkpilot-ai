import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/secure_storage_service.dart';
import '../services/api_client.dart';
import 'license_activation_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final ApiClient apiClient;
  const LoginScreen({super.key, required this.apiClient});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentApiUrl();
  }

  Future<void> _loadCurrentApiUrl() async {
    final url = await widget.apiClient.getBaseUrl();
    _apiUrlController.text = url;
  }

  Future<void> _enterProjectMode() async {
    final user = UserModel.projectUser();
    await SecureStorageService.instance.saveUserEmail('resanul@gmail.com');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DashboardScreen(
          apiClient: widget.apiClient,
          initialUser: user,
        ),
      ),
    );
  }

  Future<void> _signInWithToken(String token) async {
    if (token.trim().isEmpty) {
      setState(() => _errorMessage = 'Please provide a valid Google ID token.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Save base URL if modified
      if (_apiUrlController.text.trim().isNotEmpty) {
        widget.apiClient.setBaseUrl(_apiUrlController.text.trim());
      }

      await SecureStorageService.instance.saveAuthToken(token.trim());
      final user = await widget.apiClient.getUserProfile();
      await SecureStorageService.instance.saveUserEmail(user.email);

      if (!mounted) return;

      if (!user.hasActiveLicense) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LicenseActivationScreen(
              apiClient: widget.apiClient,
              user: user,
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              apiClient: widget.apiClient,
              initialUser: user,
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Connection failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const ink = Color(0xFF14213D);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Welcome to LinkPilot AI',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ink),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Autonomous Cybersecurity Post Automation',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),

              // Instant Project Mode button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _enterProjectMode,
                  icon: const Icon(Icons.rocket_launch, color: Colors.white, size: 20),
                  label: const Text('Enter Project Mode (Git & Direct APIs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Backend Server URL',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _apiUrlController,
                        decoration: InputDecoration(
                          hintText: 'http://10.0.2.2:8000',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Google ID Token',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _tokenController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Paste Google ID token or use QA quick tokens below',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _signInWithToken(_tokenController.text),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(_isLoading ? 'Authenticating...' : 'Sign In with Google'),
                          style: FilledButton.styleFrom(
                            backgroundColor: blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'QA / Integration Profiles',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54),
              ),
              const SizedBox(height: 8),

              _QuickAuthButton(
                icon: Icons.shield,
                label: 'Sign in as Super Admin',
                email: 'superadmin@linkpilot.io',
                onTap: () => _signInWithToken('test-token-superadmin@linkpilot.io'),
              ),
              const SizedBox(height: 8),
              _QuickAuthButton(
                icon: Icons.badge,
                label: 'Sign in as Staff Admin',
                email: 'staff1@linkpilot.io',
                onTap: () => _signInWithToken('test-token-staff1@linkpilot.io'),
              ),
              const SizedBox(height: 8),
              _QuickAuthButton(
                icon: Icons.person,
                label: 'Sign in as Customer',
                email: 'customer1@example.com',
                onTap: () => _signInWithToken('test-token-customer1@example.com'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAuthButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String email;
  final VoidCallback onTap;

  const _QuickAuthButton({
    required this.icon,
    required this.label,
    required this.email,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF2563EB)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(email, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
