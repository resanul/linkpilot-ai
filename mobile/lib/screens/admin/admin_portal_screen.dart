import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/secure_storage_service.dart';
import '../login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_licenses_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_audit_logs_screen.dart';

class AdminPortalScreen extends StatefulWidget {
  final ApiClient apiClient;

  const AdminPortalScreen({super.key, required this.apiClient});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  int _tab = 0;

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out of Admin Console?'),
        content: const Text('This will lock the administrative console and return to the main login screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    widget.apiClient.setAdminPin(null);
    await SecureStorageService.instance.clearAll();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(apiClient: widget.apiClient)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF14213D);
    const canvas = Color(0xFFF4F6FA);

    final pages = [
      AdminDashboardScreen(apiClient: widget.apiClient),
      AdminLicensesScreen(apiClient: widget.apiClient),
      AdminCustomersScreen(apiClient: widget.apiClient),
      AdminAuditLogsScreen(apiClient: widget.apiClient),
    ];

    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        backgroundColor: ink,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.shield, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text('Admin Console', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            onPressed: _signOut,
            icon: const Icon(Icons.logout, size: 16, color: Colors.white70),
            label: const Text('Exit Admin', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (v) => setState(() => _tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.key_outlined), selectedIcon: Icon(Icons.key), label: 'Licenses'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Audit Logs'),
        ],
      ),
    );
  }
}
