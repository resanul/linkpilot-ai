import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/sync_service.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'linkedin_connect_screen.dart';
import 'ai_generator_screen.dart';
import 'post_editor_screen.dart';
import 'approval_queue_screen.dart';
import 'scheduler_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'admin/admin_licenses_screen.dart';
import 'admin/admin_customers_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ApiClient apiClient;
  final UserModel initialUser;

  const DashboardScreen({
    super.key,
    required this.apiClient,
    required this.initialUser,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late UserModel _user;
  late SyncService _syncService;
  bool _adminMode = false;
  int _tab = 0;

  int _publishedCount = 0;
  int _pendingCount = 0;
  int _scheduledCount = 0;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    _syncService = SyncService(apiClient: widget.apiClient);
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() {});
    try {
      // 1. Sync posts and refresh local cache
      await _syncService.synchronize();
      final posts = await _syncService.dbService.getAllPosts();

      // 2. Fetch updated profile
      final updatedUser = await widget.apiClient.getUserProfile();

      if (!mounted) return;
      setState(() {
        _user = updatedUser;
        _publishedCount = posts.where((p) => p.status == 'published').length;
        _pendingCount = posts.where((p) => p.status == 'pending_approval').length;
        _scheduledCount = posts.where((p) => p.status == 'scheduled').length;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const canvas = Color(0xFFF4F6FA);

    final customerPages = [
      _buildHomeView(),
      HistoryScreen(apiClient: widget.apiClient, syncService: _syncService),
      SettingsScreen(
        apiClient: widget.apiClient,
        syncService: _syncService,
        user: _user,
        onUserUpdated: _refreshAll,
      ),
    ];

    final adminPages = [
      AdminDashboardScreen(apiClient: widget.apiClient),
      AdminLicensesScreen(apiClient: widget.apiClient),
      AdminCustomersScreen(apiClient: widget.apiClient),
    ];

    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        backgroundColor: canvas,
        elevation: 0,
        title: const Text('⚡ LinkPilot AI', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_user.isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('User'), icon: Icon(Icons.person_outline, size: 16)),
                  ButtonSegment(value: true, label: Text('Admin'), icon: Icon(Icons.shield_outlined, size: 16)),
                ],
                selected: {_adminMode},
                onSelectionChanged: (v) => setState(() {
                  _adminMode = v.first;
                  _tab = 0;
                }),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: _adminMode ? adminPages : customerPages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (v) => setState(() => _tab = v),
        destinations: _adminMode
            ? const [
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
                NavigationDestination(icon: Icon(Icons.key_outlined), label: 'Licenses'),
                NavigationDestination(icon: Icon(Icons.people_outline), label: 'Customers'),
              ]
            : const [
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.history), label: 'History'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
              ],
      ),
    );
  }

  Widget _buildHomeView() {
    const blue = Color(0xFF2563EB);
    const ink = Color(0xFF14213D);

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Workspace Banner
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [ink, blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PLAN: ${(_user.licensePlan ?? "STANDARD").toUpperCase()}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.security, color: Colors.white70, size: 18),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cybersecurity\nThought Leadership',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.amber, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Daily target · 20:00 Asia/Dhaka',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Real metric counters
          Row(
            children: [
              Expanded(
                child: _DashboardMetricCard(
                  'Published',
                  _publishedCount.toString(),
                  Icons.send,
                  Colors.green,
                  onTap: () => setState(() => _tab = 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardMetricCard(
                  'Pending Approval',
                  _pendingCount.toString(),
                  Icons.hourglass_top,
                  Colors.amber.shade800,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ApprovalQueueScreen(
                          apiClient: widget.apiClient,
                          syncService: _syncService,
                        ),
                      ),
                    );
                    _refreshAll();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardMetricCard(
                  'Scheduled',
                  _scheduledCount.toString(),
                  Icons.schedule,
                  blue,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SchedulerScreen(
                          apiClient: widget.apiClient,
                          syncService: _syncService,
                        ),
                      ),
                    );
                    _refreshAll();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Text('LINKEDIN ACCOUNT INTEGRATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: const Icon(Icons.business_center, color: Color(0xFF0A66C2)),
              title: Text(
                _user.linkedinConnected
                    ? 'Connected: ${_user.linkedinProfileName ?? "Personal Profile"}'
                    : 'Connect LinkedIn Account',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                _user.linkedinConnected ? 'Official OAuth active · Ready to publish' : 'Required before publishing posts',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: FilledButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LinkedInConnectScreen(
                        apiClient: widget.apiClient,
                        onStatusChanged: _refreshAll,
                      ),
                    ),
                  );
                  _refreshAll();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _user.linkedinConnected ? Colors.grey.shade700 : const Color(0xFF0A66C2),
                ),
                child: Text(_user.linkedinConnected ? 'Manage' : 'Connect'),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text('ACTIONS & WORKFLOW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),

          _ActionCard(
            icon: Icons.auto_awesome,
            color: blue,
            title: 'Generate with AI Studio',
            subtitle: 'Synthesize original cybersecurity posts with Google Gemini',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AIGeneratorScreen(
                    apiClient: widget.apiClient,
                    syncService: _syncService,
                  ),
                ),
              );
              _refreshAll();
            },
          ),
          const SizedBox(height: 8),
          _ActionCard(
            icon: Icons.edit_note,
            color: Colors.teal,
            title: 'Compose Custom Post',
            subtitle: 'Draft and schedule manual thought leadership content',
            onTap: () async {
              final res = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => PostEditorScreen(
                    apiClient: widget.apiClient,
                    syncService: _syncService,
                  ),
                ),
              );
              if (res == true) _refreshAll();
            },
          ),
          const SizedBox(height: 8),
          _ActionCard(
            icon: Icons.checklist_rtl,
            color: Colors.amber.shade800,
            title: 'Review Approval Queue',
            subtitle: '$_pendingCount posts awaiting approval before dispatch',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ApprovalQueueScreen(
                    apiClient: widget.apiClient,
                    syncService: _syncService,
                  ),
                ),
              );
              _refreshAll();
            },
          ),
          const SizedBox(height: 8),
          _ActionCard(
            icon: Icons.alarm,
            color: ink,
            title: 'Publishing Scheduler',
            subtitle: 'View upcoming automated daily dispatch at 20:00 Asia/Dhaka',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SchedulerScreen(
                    apiClient: widget.apiClient,
                    syncService: _syncService,
                  ),
                ),
              );
              _refreshAll();
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardMetricCard(this.title, this.value, this.icon, this.color, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(color: Colors.black54, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.color,
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
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black38),
      ),
    );
  }
}
