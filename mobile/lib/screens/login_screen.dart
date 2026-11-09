import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/secure_storage_service.dart';
import '../services/api_client.dart';
import 'license_activation_screen.dart';
import 'dashboard_screen.dart';

enum LoginTab { user, admin }

class LoginScreen extends StatefulWidget {
  final ApiClient apiClient;
  const LoginScreen({super.key, required this.apiClient});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  LoginTab _currentTab = LoginTab.user;
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();
  final TextEditingController _adminPinController = TextEditingController(text: '889900');
  final TextEditingController _adminEmailController = TextEditingController(text: 'admin@linkpilot.ai');
  bool _obscureAdminPin = true;
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
          initialAdminMode: false,
        ),
      ),
    );
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
      if (_apiUrlController.text.trim().isNotEmpty) {
        widget.apiClient.setBaseUrl(_apiUrlController.text.trim());
      }

      if (pin != '889900' && pin != 'admin') {
        throw ApiException(403, 'Invalid Master Admin PIN. Access Denied.');
      }

      widget.apiClient.setAdminPin(pin);
      final adminEmail = _adminEmailController.text.trim().isNotEmpty
          ? _adminEmailController.text.trim()
          : 'admin@linkpilot.ai';

      await SecureStorageService.instance.saveUserEmail(adminEmail);

      UserModel adminUser;
      try {
        adminUser = await widget.apiClient.getUserProfile();
      } catch (_) {
        adminUser = UserModel.adminUser(email: adminEmail);
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            apiClient: widget.apiClient,
            initialUser: adminUser,
            initialAdminMode: true,
          ),
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

  Future<void> _signInWithToken(String token, {bool forceAdmin = false}) async {
    if (token.trim().isEmpty) {
      setState(() => _errorMessage = 'Please provide a valid Google ID token.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_apiUrlController.text.trim().isNotEmpty) {
        widget.apiClient.setBaseUrl(_apiUrlController.text.trim());
      }

      if (forceAdmin) {
        widget.apiClient.setAdminPin('889900');
      } else {
        widget.apiClient.setAdminPin(null);
      }

      await SecureStorageService.instance.saveAuthToken(token.trim());
      final user = await widget.apiClient.getUserProfile();
      await SecureStorageService.instance.saveUserEmail(user.email);

      if (!mounted) return;

      if (!forceAdmin && !user.isAdmin && !user.hasActiveLicense) {
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
              initialAdminMode: forceAdmin || user.isAdmin,
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 38),
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'Welcome to LinkPilot AI',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ink),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  _currentTab == LoginTab.user
                      ? 'Autonomous Cybersecurity Post Automation for Clients'
                      : 'Commercial License & Customer Administration Portal',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),

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
                              Icon(Icons.person, size: 18, color: _currentTab == LoginTab.user ? Colors.white : Colors.black87),
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
                              Icon(Icons.shield, size: 18, color: _currentTab == LoginTab.admin ? Colors.amber : Colors.black87),
                              const SizedBox(width: 8),
                              Text(
                                'Admin Login',
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
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // ================= USER LOGIN FORM =================
              if (_currentTab == LoginTab.user) ...[
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
                const SizedBox(height: 20),

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
                            hintText: 'http://10.0.2.2:8001',
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
                            hintText: 'Paste Google ID token or select a customer profile below',
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
                                : () => _signInWithToken(_tokenController.text, forceAdmin: false),
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

                const SizedBox(height: 20),
                const Text(
                  'QA / Integration Profiles',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54),
                ),
                const SizedBox(height: 8),

                _QuickAuthButton(
                  icon: Icons.shield,
                  label: 'Sign in as Super Admin',
                  email: 'superadmin@linkpilot.io',
                  onTap: () => _signInWithToken('test-token-superadmin@linkpilot.io', forceAdmin: true),
                ),
                const SizedBox(height: 8),
                _QuickAuthButton(
                  icon: Icons.person,
                  label: 'Sign in as Customer',
                  email: 'customer1@example.com',
                  onTap: () => _signInWithToken('test-token-customer1@example.com', forceAdmin: false),
                ),
              ],

              // ================= ADMIN LOGIN FORM =================
              if (_currentTab == LoginTab.admin) ...[
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
                        Row(
                          children: const [
                            Icon(Icons.shield, color: Colors.amber, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Master Admin Credentials',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ink),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Enter the Master PIN to access the license minting and customer administration console.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),

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
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureAdminPin ? Icons.visibility : Icons.visibility_off, size: 20),
                              onPressed: () => setState(() => _obscureAdminPin = !_obscureAdminPin),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Text(
                          'Administrator Email (Optional)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _adminEmailController,
                          decoration: InputDecoration(
                            hintText: 'admin@linkpilot.ai',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Text(
                          'Backend Server URL',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _apiUrlController,
                          decoration: InputDecoration(
                            hintText: 'http://10.0.2.2:8001',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : _signInAsAdmin,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.admin_panel_settings, color: Colors.amber),
                            label: Text(
                              _isLoading ? 'Verifying Admin PIN...' : 'Unlock & Sign In as Admin',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

                const SizedBox(height: 20),
                const Text(
                  'Quick Administrator Profiles',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54),
                ),
                const SizedBox(height: 8),

                _QuickAuthButton(
                  icon: Icons.shield,
                  label: 'Sign in as Super Admin',
                  email: 'superadmin@linkpilot.io',
                  onTap: () => _signInWithToken('test-token-superadmin@linkpilot.io', forceAdmin: true),
                ),
                const SizedBox(height: 8),
                _QuickAuthButton(
                  icon: Icons.badge,
                  label: 'Sign in as Staff Admin',
                  email: 'staff1@linkpilot.io',
                  onTap: () => _signInWithToken('test-token-staff1@linkpilot.io', forceAdmin: true),
                ),
              ],
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
