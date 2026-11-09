import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';
import '../services/api_client.dart';
import 'login_screen.dart';
import 'license_activation_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  final ApiClient apiClient;
  const SplashScreen({super.key, required this.apiClient});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Initializing LinkPilot AI...';

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final token = await SecureStorageService.instance.getAuthToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LoginScreen(apiClient: widget.apiClient)),
      );
      return;
    }

    setState(() => _status = 'Verifying license & profile...');
    try {
      final user = await widget.apiClient.getUserProfile();
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
    } catch (e) {
      if (!mounted) return;
      // Network error or invalid token: go to Login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LoginScreen(apiClient: widget.apiClient)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14213D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'LinkPilot AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Autonomous Cybersecurity Thought Leadership',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Color(0xFF2563EB),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
