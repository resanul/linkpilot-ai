import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import 'admin_licenses_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_staff_screen.dart';
import 'admin_audit_logs_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final ApiClient apiClient;

  const AdminDashboardScreen({super.key, required this.apiClient});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _overview;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOverview();
  }

  Future<void> _fetchOverview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await widget.apiClient.getAdminOverview();
      if (!mounted) return;
      setState(() => _overview = res);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load metrics: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const ink = Color(0xFF14213D);

    final customersCount = _overview?['customers']?.toString() ?? '—';
    final activeLicCount = _overview?['active_licenses']?.toString() ?? '—';
    final assignedLicCount = _overview?['assigned_licenses']?.toString() ?? '—';
    final publishedPosts = _overview?['published_posts']?.toString() ?? '—';
    final adminRole = _overview?['admin_role']?.toString().toUpperCase() ?? 'ADMIN';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Admin Operations Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh Metrics',
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOverview,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchOverview,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),

                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: blue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                adminRole,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.shield, color: Colors.white54, size: 18),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Commercial Operations Console',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Real-time SaaS metrics, license provisioning, and customer audits.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text('BUSINESS METRICS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(child: _AdminMetricCard('Total Customers', customersCount, Icons.people, blue)),
                      const SizedBox(width: 12),
                      Expanded(child: _AdminMetricCard('Active Licenses', activeLicCount, Icons.key, Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _AdminMetricCard('Assigned Licenses', assignedLicCount, Icons.assignment_turned_in, Colors.indigo)),
                      const SizedBox(width: 12),
                      Expanded(child: _AdminMetricCard('Published Posts', publishedPosts, Icons.send, Colors.teal)),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text('ADMIN MODULES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 10),

                  _AdminNavCard(
                    icon: Icons.key,
                    title: 'License Provisioning',
                    subtitle: 'Issue, view, and revoke Standard, Pro, and Business keys',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => AdminLicensesScreen(apiClient: widget.apiClient)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _AdminNavCard(
                    icon: Icons.people,
                    title: 'Customer Directory',
                    subtitle: 'View registered customers and active entitlements',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => AdminCustomersScreen(apiClient: widget.apiClient)),
                    ),
                  ),
                  if (adminRole == 'SUPER_ADMIN') ...[
                    const SizedBox(height: 10),
                    _AdminNavCard(
                      icon: Icons.admin_panel_settings,
                      title: 'Staff Administration',
                      subtitle: 'Add and revoke Staff Admin privileges',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AdminStaffScreen(apiClient: widget.apiClient)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AdminNavCard(
                      icon: Icons.security_update_good,
                      title: 'Security Audit Logs',
                      subtitle: 'Inspect immutable administrative and publishing audit trails',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AdminAuditLogsScreen(apiClient: widget.apiClient)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _AdminMetricCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;

  const _AdminMetricCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _AdminNavCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  const _AdminNavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black38),
      ),
    );
  }
}
