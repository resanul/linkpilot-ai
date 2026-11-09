import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';

class LinkedInConnectScreen extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback? onStatusChanged;

  const LinkedInConnectScreen({
    super.key,
    required this.apiClient,
    this.onStatusChanged,
  });

  @override
  State<LinkedInConnectScreen> createState() => _LinkedInConnectScreenState();
}

class _LinkedInConnectScreenState extends State<LinkedInConnectScreen> {
  bool _isLoading = true;
  bool _isConnected = false;
  String? _profileName;
  String? _personUrn;
  DateTime? _expiresAt;
  bool _tokenExpired = false;
  String? _authUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final status = await widget.apiClient.getLinkedInStatus();
      if (!mounted) return;
      setState(() {
        _isConnected = (status['connected'] as bool?) ?? false;
        _profileName = status['profile_name'] as String?;
        _personUrn = status['person_urn'] as String?;
        _tokenExpired = (status['token_expired'] as bool?) ?? false;
        if (status['expires_at'] != null) {
          _expiresAt = DateTime.tryParse(status['expires_at'] as String);
        }
      });
      widget.onStatusChanged?.call();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load status: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startConnectFlow() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final url = await widget.apiClient.getLinkedInConnectUrl();
      if (!mounted) return;
      setState(() {
        _authUrl = url;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to generate OAuth URL: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect LinkedIn?'),
        content: const Text(
          'Are you sure you want to disconnect your LinkedIn account? Scheduled posts will fail until an account is reconnected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await widget.apiClient.disconnectLinkedIn();
      await _fetchStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LinkedIn account disconnected.')),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const linkedInBlue = Color(0xFF0A66C2);
    const ink = Color(0xFF14213D);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('LinkedIn Connection', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh Status',
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: linkedInBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.business_center, color: linkedInBlue, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('LinkedIn Account',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _isConnected
                                            ? (_tokenExpired ? Colors.orange.shade100 : Colors.green.shade100)
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _isConnected
                                            ? (_tokenExpired ? 'TOKEN EXPIRED' : 'CONNECTED')
                                            : 'NOT CONNECTED',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          color: _isConnected
                                              ? (_tokenExpired ? Colors.orange.shade800 : Colors.green.shade800)
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),

                          if (_isConnected) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person, color: ink),
                              title: const Text('Connected Profile', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              subtitle: Text(_profileName ?? 'LinkedIn Member',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            if (_personUrn != null)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.fingerprint, color: ink),
                                title: const Text('Member URN', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                subtitle: Text(_personUrn!, style: const TextStyle(fontSize: 13)),
                              ),
                            if (_expiresAt != null)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.timer_outlined, color: ink),
                                title: const Text('Token Valid Until', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                subtitle: Text(
                                  _expiresAt!.toLocal().toString().split('.').first,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _tokenExpired ? Colors.red : Colors.black87,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _disconnect,
                                icon: const Icon(Icons.link_off, color: Colors.red),
                                label: const Text('Disconnect Account', style: TextStyle(color: Colors.red)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ] else ...[
                            const Text(
                              'Connect your official personal LinkedIn profile. LinkPilot AI uses LinkedIn OAuth 2.0 with OIDC and Posts API permissions to publish approved cybersecurity insights directly to your feed.',
                              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: FilledButton.icon(
                                onPressed: _startConnectFlow,
                                icon: const Icon(Icons.open_in_browser),
                                label: const Text('Authorize LinkedIn Account'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: linkedInBlue,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (_authUrl != null && !_isConnected) ...[
                    const SizedBox(height: 20),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: blue.withValues(alpha: 0.3)),
                      ),
                      color: blue.withValues(alpha: 0.04),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.link, color: blue),
                                SizedBox(width: 8),
                                Text('Authorization URL Generated',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Open this URL in your browser to authorize LinkPilot AI on LinkedIn, then return here and tap Refresh Status:',
                              style: TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: SelectableText(
                                _authUrl!,
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: _authUrl!));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('URL copied to clipboard!')),
                                      );
                                    },
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('Copy URL'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _fetchStatus,
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Verify Connection'),
                                    style: FilledButton.styleFrom(backgroundColor: blue),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security, size: 18, color: blue),
                            SizedBox(width: 8),
                            Text('DevSecOps Security Notice',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: blue)),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          '• LinkPilot AI NEVER requests or stores your LinkedIn password or cookies.\n'
                          '• All tokens are encrypted at rest with Fernet cryptography.\n'
                          '• Only one official LinkedIn account can be connected per customer.\n'
                          '• State tokens expire in 10 minutes and prevent replay attacks.',
                          style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
