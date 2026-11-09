import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/secure_storage_service.dart';
import '../services/sync_service.dart';
import 'login_screen.dart';
import 'linkedin_connect_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ApiClient apiClient;
  final SyncService syncService;
  final UserModel user;
  final VoidCallback onUserUpdated;

  const SettingsScreen({
    super.key,
    required this.apiClient,
    required this.syncService,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiUrlController = TextEditingController();
  bool _isSavingUrl = false;

  @override
  void initState() {
    super.initState();
    _loadApiUrl();
  }

  Future<void> _loadApiUrl() async {
    final url = await widget.apiClient.getBaseUrl();
    _apiUrlController.text = url;
  }

  Future<void> _saveApiUrl() async {
    setState(() => _isSavingUrl = true);
    widget.apiClient.setBaseUrl(_apiUrlController.text.trim());
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _isSavingUrl = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API Server URL updated.')),
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out from LinkPilot AI?'),
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

    await SecureStorageService.instance.clearAll();
    await widget.syncService.dbService.clearAllPosts();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(apiClient: widget.apiClient)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Account & Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User identity card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0x1A2563EB),
                      child: const Icon(Icons.person, color: blue, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.user.email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text('ID: ${widget.user.id}', style: const TextStyle(color: Colors.black45, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text('COMMERCIAL LICENSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _SettingRow(
                      icon: Icons.workspace_premium,
                      title: 'Subscription Tier',
                      value: (widget.user.licensePlan ?? 'Standard').toUpperCase(),
                      highlight: true,
                    ),
                    const Divider(height: 20),
                    _SettingRow(
                      icon: Icons.calendar_month,
                      title: 'Billing Cycle',
                      value: (widget.user.licenseCycle ?? 'Monthly').toUpperCase(),
                    ),
                    const Divider(height: 20),
                    _SettingRow(
                      icon: Icons.timer,
                      title: 'Expires At',
                      value: widget.user.licenseExpiresAt != null
                          ? DateFormat('yyyy-MM-dd').format(widget.user.licenseExpiresAt!)
                          : 'Lifetime License (No Expiry)',
                    ),
                    const Divider(height: 20),
                    _SettingRow(
                      icon: Icons.devices,
                      title: 'Connected Devices Limit',
                      value: '1 Mobile Device',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text('LINKEDIN INTEGRATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: const Icon(Icons.business_center, color: Color(0xFF0A66C2)),
                title: const Text('LinkedIn Connection Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                  widget.user.linkedinConnected
                      ? 'Connected as ${widget.user.linkedinProfileName ?? "Personal Profile"}'
                      : 'Not connected. Connect to enable publishing.',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LinkedInConnectScreen(
                        apiClient: widget.apiClient,
                        onStatusChanged: widget.onUserUpdated,
                      ),
                    ),
                  );
                  widget.onUserUpdated();
                },
              ),
            ),

            const SizedBox(height: 16),
            const Text('DEVELOPER & SERVER CONFIGURATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Backend API Server URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _apiUrlController,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _isSavingUrl ? null : _saveApiUrl,
                          child: _isSavingUrl
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Sign Out of LinkPilot AI', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool highlight;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: highlight ? const Color(0xFF2563EB) : Colors.black54),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: highlight ? const Color(0xFF2563EB) : Colors.black87,
          ),
        ),
      ],
    );
  }
}
