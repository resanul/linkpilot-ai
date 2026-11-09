import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';

class AdminAuditLogsScreen extends StatefulWidget {
  final ApiClient apiClient;

  const AdminAuditLogsScreen({super.key, required this.apiClient});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.apiClient.getAdminAuditLogs();
      if (!mounted) return;
      setState(() => _logs = list);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _actionColor(String action) {
    if (action.contains('REVOKE') || action.contains('DELETE') || action.contains('REJECT')) {
      return Colors.red;
    }
    if (action.contains('CREATE') || action.contains('ACTIVATE') || action.contains('PUBLISH')) {
      return Colors.green;
    }
    return const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Security Audit Trails', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0,
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _loadLogs),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: _logs.isEmpty
                  ? const Center(child: Text('No audit log entries recorded.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final action = log['action'] as String? ?? 'UNKNOWN';
                        final actor = log['actor_email'] as String? ?? log['actor_id'] as String? ?? 'System';
                        final details = log['details'] as String?;
                        final createdAt = log['created_at'] != null ? DateTime.tryParse(log['created_at'] as String) : null;
                        final color = _actionColor(action);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        action,
                                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (createdAt != null)
                                      Text(
                                        DateFormat('yyyy-MM-dd HH:mm').format(createdAt),
                                        style: const TextStyle(fontSize: 11, color: Colors.black45),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Actor: $actor', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                if (details != null && details.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(details, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
