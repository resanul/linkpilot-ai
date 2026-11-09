import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/secure_storage_service.dart';
import '../services/api_client.dart';
import '../services/github_cloud_service.dart';
import 'license_activation_screen.dart';
import 'pending_approval_screen.dart';
import 'dashboard_screen.dart';
import 'admin/admin_portal_screen.dart';

enum LoginTab { user, admin }

class LoginScreen extends StatefulWidget {
  final ApiClient apiClient;
  const LoginScreen({super.key, required this.apiClient});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  LoginTab _currentTab = LoginTab.user;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _adminPinController = TextEditingController(text: '889900');
  final TextEditingController _apiUrlController = TextEditingController();
  bool _obscureAdminPin = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showAdvancedSettings = false;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final savedEmail = await SecureStorageService.instance.getUserEmail();
    if (savedEmail != null && savedEmail.isNotEmpty && _emailController.text.isEmpty) {
      _emailController.text = savedEmail;
    }
    final url = await widget.apiClient.getBaseUrl();
    _apiUrlController.text = url;
  }

  Future<void> _handleGoogleAuth({required bool isSignUp}) async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Please enter a valid Google (Gmail) address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Authenticate or register with GitHub Cloud Backend
      final UserModel user = await GitHubCloudService.instance.registerOrLoginGoogleUser(email);

      await SecureStorageService.instance.saveUserEmail(user.email);
      await SecureStorageService.instance.saveAuthToken('token-${user.email}');
      widget.apiClient.setAdminPin(null);

      if (!mounted) return;

      if (user.isAdmin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AdminPortalScreen(apiClient: widget.apiClient),
          ),
        );
      } else if (!user.isApproved) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PendingApprovalScreen(
              apiClient: widget.apiClient,
              user: user,
            ),
          ),
        );
      } else if (!user.hasActiveLicense) {
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
    } catch (e) {
      setState(() => _errorMessage = 'Authentication failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAsAdmin() async {
    final pin = _adminPinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Please enter the Master Admin PIN.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (pin != '889900' && pin != 'admin') {
        throw ApiException(403, 'Invalid Master Admin PIN. Access Denied.');
      }

      widget.apiClient.setAdminPin(pin);
      await SecureStorageService.instance.saveUserEmail('admin@linkpilot.ai');

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AdminPortalScreen(apiClient: widget.apiClient),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Admin sign-in failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enterOwnerMode() async {
    _emailController.text = 'resanul@gmail.com';
    await _handleGoogleAuth(isSignUp: false);
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const ink = Color(0xFF14213D);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: ink.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'LinkPilot AI',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Autonomous Cybersecurity Thought Leadership',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),

              // Tab Switcher: User Login vs Admin Login
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _currentTab = LoginTab.user;
                          _errorMessage = null;
                        }),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _currentTab == LoginTab.user ? blue : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 18,
                                color: _currentTab == LoginTab.user ? Colors.white : Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'User Login',
                                style: TextStyle(
                                  color: _currentTab == LoginTab.user ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _currentTab = LoginTab.admin;
                          _errorMessage = null;
                        }),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _currentTab == LoginTab.admin ? ink : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 18,
                                color: _currentTab == LoginTab.admin ? Colors.amber : Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Admin Console',
                                style: TextStyle(
                                  color: _currentTab == LoginTab.admin ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

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
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // ================= USER GOOGLE LOGIN =================
              if (_currentTab == LoginTab.user) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  'G',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Continue with Google',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    'Sign in or sign up with your Google account',
                                    style: TextStyle(color: Colors.black54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Google Account Email',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'e.g. yourname@gmail.com',
                            prefixIcon: const Icon(Icons.mail_outline, size: 20),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Sign In with Google Button
                        SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : () => _handleGoogleAuth(isSignUp: false),
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              _isLoading ? 'Verifying with Cloud...' : 'Sign In with Google',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: blue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Sign Up with Google Button
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : () => _handleGoogleAuth(isSignUp: true),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: const Text(
                              'Sign Up with Google (New Account)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: blue,
                              side: BorderSide(color: blue.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Quick Project Owner Sign In
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _enterOwnerMode,
                  icon: const Icon(Icons.verified_user, color: Color(0xFF16A34A), size: 18),
                  label: const Text(
                    'Instant Sign In as Project Owner (resanul@gmail.com)',
                    style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.green.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],

              // ================= ADMIN CONSOLE TAB =================
              if (_currentTab == LoginTab.admin) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield, color: Colors.amber, size: 28),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Master Administrator',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ink),
                                ),
                                Text(
                                  'Customer approval & license management',
                                  style: TextStyle(color: Colors.black54, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Master Admin Security PIN',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _adminPinController,
                          obscureText: _obscureAdminPin,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Default PIN: 889900',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureAdminPin ? Icons.visibility : Icons.visibility_off, size: 20),
                              onPressed: () => setState(() => _obscureAdminPin = !_obscureAdminPin),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : _signInAsAdmin,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.admin_panel_settings_rounded),
                            label: const Text(
                              'Enter Admin Console',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: ink,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Backend Cloud Status Footer
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Backend Cloud: GitHub (resanul/linkpilot-ai)',
                      style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Expandable Developer Settings (Hidden by default)
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _showAdvancedSettings = !_showAdvancedSettings),
                  icon: Icon(
                    _showAdvancedSettings ? Icons.expand_less : Icons.settings_outlined,
                    size: 16,
                    color: Colors.black38,
                  ),
                  label: Text(
                    _showAdvancedSettings ? 'Hide Developer Settings' : 'Advanced Developer Settings',
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ),
              ),

              if (_showAdvancedSettings) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Custom API Server (Optional Override)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _apiUrlController,
                        decoration: InputDecoration(
                          hintText: 'http://10.0.2.2:8001',
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          if (val.trim().isNotEmpty) {
                            widget.apiClient.setBaseUrl(val.trim());
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
