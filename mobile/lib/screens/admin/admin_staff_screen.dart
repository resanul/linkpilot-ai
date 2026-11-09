import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';

class AdminStaffScreen extends StatefulWidget {
  final ApiClient apiClient;

  const AdminStaffScreen({super.key, required this.apiClient});

  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  List<Map<String, dynamic>> _staff = [];
  bool _isLoading = true;
  final TextEditingController _emailController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await widget.apiClient.getAdminStaff();
      if (!mounted) return;
      setState(() => _staff = list);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load staff: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addStaff() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Google account email.')),
      );
      return;
    }

    try {
      await widget.apiClient.addAdminStaff(email);
      _emailController.clear();
      await _loadStaff();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Staff admin $email added successfully.'), backgroundColor: Colors.green),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _revokeStaff(Map<String, dynamic> item) async {
    final staffId = item['id'] as String;
    final email = item['email'] as String;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Staff Access?'),
        content: Text('Are you sure you want to revoke staff privileges from $email?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.apiClient.revokeAdminStaff(staffId);
      await _loadStaff();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Staff access revoked for $email.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showAddStaffDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Staff Administrator'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Google email address of the person you want to authorize as a Staff Admin:',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'colleague@example.com',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: _addStaff,
            child: const Text('Authorize Staff'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Staff Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0,
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _loadStaff),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffDialog,
        backgroundColor: blue,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStaff,
              child: Column(
                children: [
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  Expanded(
                    child: _staff.isEmpty
                        ? const Center(child: Text('No staff administrators configured.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _staff.length,
                            itemBuilder: (context, index) {
                              final s = _staff[index];
                              final email = s['email'] as String;
                              final active = s['active'] as bool? ?? true;
                              final createdAt = s['created_at'] != null ? DateTime.tryParse(s['created_at'] as String) : null;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: active ? blue.withValues(alpha: 0.1) : Colors.grey.shade200,
                                    child: Icon(Icons.badge, color: active ? blue : Colors.grey),
                                  ),
                                  title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text(
                                    createdAt != null ? 'Added: ${DateFormat('yyyy-MM-dd').format(createdAt)}' : '',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: active
                                      ? OutlinedButton(
                                          onPressed: () => _revokeStaff(s),
                                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                                          child: const Text('Revoke', style: TextStyle(color: Colors.red, fontSize: 12)),
                                        )
                                      : const Text('REVOKED', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
