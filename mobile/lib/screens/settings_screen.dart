import 'package:flutter/material.dart';
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
  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _linkedInTokenController = TextEditingController();
  final TextEditingController _customTopicController = TextEditingController();

  bool _isSavingUrl = false;
  bool _isSavingGeminiKey = false;
  bool _isConnectingLinkedIn = false;
  bool _obscureGeminiKey = true;

  final List<String> _availableDomains = [
    'SOC operations',
    'SIEM and threat detection',
    'Incident response',
    'Vulnerability management',
    'Penetration testing',
    'Cloud security',
    'Network security',
    'Application security',
    'MITRE ATT&CK',
    'Threat intelligence',
    'Security awareness',
    'Emerging cybersecurity trends'
  ];

  List<String> _selectedTopics = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final url = await widget.apiClient.getBaseUrl();
    final geminiKey = await SecureStorageService.instance.getGeminiApiKey();
    final savedTopics = await SecureStorageService.instance.getPreferredTopics();

    if (!mounted) return;
    setState(() {
      _apiUrlController.text = url;
      if (geminiKey != null) _geminiKeyController.text = geminiKey;
      _selectedTopics = savedTopics.isNotEmpty
          ? List.from(savedTopics)
          : ['Cloud security', 'Threat intelligence', 'Incident response'];
    });
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

  Future<void> _saveGeminiKey() async {
    setState(() => _isSavingGeminiKey = true);
    final key = _geminiKeyController.text.trim();
    await SecureStorageService.instance.saveGeminiApiKey(key);
    if (!mounted) return;
    setState(() => _isSavingGeminiKey = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(key.isEmpty ? 'Gemini API Key removed.' : 'Gemini API Key saved securely!')),
    );
  }

  Future<void> _connectLinkedInManual() async {
    final token = _linkedInTokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a valid LinkedIn Access Token.')),
      );
      return;
    }

    setState(() => _isConnectingLinkedIn = true);
    try {
      final res = await widget.apiClient.connectLinkedInManual(token);
      await SecureStorageService.instance.saveLinkedInToken(token);
      widget.onUserUpdated();
      if (!mounted) return;
      _linkedInTokenController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('LinkedIn connected successfully: ${res["profile_name"]}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isConnectingLinkedIn = false);
    }
  }

  Future<void> _toggleTopic(String topic) async {
    setState(() {
      if (_selectedTopics.contains(topic)) {
        _selectedTopics.remove(topic);
      } else {
        _selectedTopics.add(topic);
      }
    });
    await SecureStorageService.instance.savePreferredTopics(_selectedTopics);
  }

  Future<void> _addCustomTopic() async {
    final custom = _customTopicController.text.trim();
    if (custom.isEmpty) return;
    setState(() {
      if (!_selectedTopics.contains(custom)) {
        _selectedTopics.add(custom);
      }
      if (!_availableDomains.contains(custom)) {
        _availableDomains.insert(0, custom);
      }
      _customTopicController.clear();
    });
    await SecureStorageService.instance.savePreferredTopics(_selectedTopics);
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
                          const SizedBox(height: 4),
                          Text(
                            'Plan: ${(widget.user.licensePlan ?? "ENTERPRISE").toUpperCase()} · ${widget.user.daysRemaining != null ? "${widget.user.daysRemaining} days remaining" : "Active"}',
                            style: const TextStyle(color: blue, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text('API KEYS & INTEGRATIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),

            // Google Gemini API Key Card
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
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, color: Color(0xFF7C3AED), size: 20),
                        SizedBox(width: 8),
                        Text('Google Gemini API Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Used to generate technical cybersecurity posts on-device or via cloud.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _geminiKeyController,
                      obscureText: _obscureGeminiKey,
                      decoration: InputDecoration(
                        hintText: 'AIzaSy...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureGeminiKey ? Icons.visibility : Icons.visibility_off, size: 20),
                          onPressed: () => setState(() => _obscureGeminiKey = !_obscureGeminiKey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _isSavingGeminiKey ? null : _saveGeminiKey,
                        icon: const Icon(Icons.check, size: 16),
                        label: Text(_isSavingGeminiKey ? 'Saving...' : 'Save Gemini Key'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Direct LinkedIn Access Token Card
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
                    Row(
                      children: [
                        const Icon(Icons.business_center, color: Color(0xFF0A66C2), size: 20),
                        const SizedBox(width: 8),
                        const Text('LinkedIn Token & Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.user.linkedinConnected ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.user.linkedinConnected ? 'Connected' : 'Disconnected',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: widget.user.linkedinConnected ? Colors.green.shade700 : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.user.linkedinConnected
                          ? 'Publishing as: ${widget.user.linkedinProfileName ?? "Personal Profile"}'
                          : 'Paste your 60-day OAuth token or click OAuth Connect below.',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _linkedInTokenController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Paste LinkedIn Access Token (AQV...)',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
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
                          child: const Text('OAuth Browser Login'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _isConnectingLinkedIn ? null : _connectLinkedInManual,
                          icon: const Icon(Icons.link, size: 16),
                          label: Text(_isConnectingLinkedIn ? 'Connecting...' : 'Connect Token'),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0A66C2)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text('PREFERRED TOPICS (CYBERSECURITY DOMAINS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),

            // Topics Preferences Card
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
                    const Text('Select topics to prioritize for automated & AI post generation:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableDomains.map((domain) {
                        final isSelected = _selectedTopics.contains(domain);
                        return FilterChip(
                          label: Text(domain, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                          selected: isSelected,
                          selectedColor: blue,
                          checkmarkColor: Colors.white,
                          backgroundColor: Colors.grey.shade100,
                          onSelected: (_) => _toggleTopic(domain),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Add Custom Topic / Focus Area:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customTopicController,
                            decoration: InputDecoration(
                              hintText: 'e.g., Active Directory Kerberoasting',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _addCustomTopic,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text('GIT AUTOMATION & SCHEDULE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
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
                      icon: Icons.code,
                      title: 'GitHub Repository',
                      value: 'resanul/linkpilot-ai',
                      highlight: true,
                    ),
                    const Divider(height: 20),
                    _SettingRow(
                      icon: Icons.access_time_filled,
                      title: 'Autonomous Daily Post',
                      value: '20:00 Asia/Dhaka (14:00 UTC)',
                    ),
                    const Divider(height: 20),
                    _SettingRow(
                      icon: Icons.storage,
                      title: 'Execution Mode',
                      value: 'Serverless (GitHub Actions + Phone)',
                      highlight: true,
                    ),
                    const Divider(height: 20),
                    _SettingRow(
                      icon: Icons.history_edu,
                      title: 'Database Persistence',
                      value: 'SQLite (On Phone + Git commits)',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text('OPTIONAL LOCAL SERVER (DISABLED BY DEFAULT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
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
                    const Text('Local FastAPI Server URL (Not needed for Git mode)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text('Leave as default. Direct on-device and Git automation is active.', style: TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 10),
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
