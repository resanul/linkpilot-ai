import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';

enum CustomerFilter { all, pending, approved }

class AdminCustomersScreen extends StatefulWidget {
  final ApiClient apiClient;

  const AdminCustomersScreen({super.key, required this.apiClient});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _errorMessage;
  CustomerFilter _activeFilter = CustomerFilter.all;
  final Set<String> _processingUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await widget.apiClient.getAdminCustomers();
      if (!mounted) return;
      setState(() => _customers = list);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load customers: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveCustomer(String userId, String email) async {
    setState(() => _processingUserIds.add(userId));
    try {
      await widget.apiClient.approveAdminCustomer(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account approved: $email'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      await _loadCustomers();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval failed: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processingUserIds.remove(userId));
    }
  }

  Future<void> _rejectCustomer(String userId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject / Suspend Account?'),
        content: Text('Are you sure you want to reject and revoke access for $email?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject Account'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingUserIds.add(userId));
    try {
      await widget.apiClient.rejectAdminCustomer(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account rejected/suspended: $email'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      await _loadCustomers();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reject failed: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reject error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processingUserIds.remove(userId));
    }
  }

  int get _pendingCount =>
      _customers.where((c) => (c['is_approved'] as bool?) == false).length;

  List<Map<String, dynamic>> get _filteredCustomers {
    var list = _customers;
    if (_activeFilter == CustomerFilter.pending) {
      list = list.where((c) => (c['is_approved'] as bool?) == false).toList();
    } else if (_activeFilter == CustomerFilter.approved) {
      list = list.where((c) => (c['is_approved'] as bool?) == true).toList();
    }

    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((c) {
      final email = (c['email'] as String? ?? '').toLowerCase();
      final id = (c['id'] as String? ?? '').toLowerCase();
      return email.contains(q) || id.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Customer Directory', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0,
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _loadCustomers),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search by customer email or ID...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),

                // Filter Tabs: All, Pending Approval, Approved
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'All (${_customers.length})',
                          isSelected: _activeFilter == CustomerFilter.all,
                          onTap: () => setState(() => _activeFilter = CustomerFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Pending Approval ($_pendingCount)',
                          isSelected: _activeFilter == CustomerFilter.pending,
                          isHighlight: _pendingCount > 0,
                          onTap: () => setState(() => _activeFilter = CustomerFilter.pending),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Approved (${_customers.length - _pendingCount})',
                          isSelected: _activeFilter == CustomerFilter.approved,
                          onTap: () => setState(() => _activeFilter = CustomerFilter.approved),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadCustomers,
                    child: _filteredCustomers.isEmpty
                        ? const Center(child: Text('No customers found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredCustomers.length,
                            itemBuilder: (context, index) {
                              final c = _filteredCustomers[index];
                              final email = c['email'] as String? ?? 'Unknown';
                              final id = c['id'] as String? ?? '';
                              final isApproved = c['is_approved'] as bool? ?? false;
                              final hasLic = c['has_active_license'] as bool? ?? false;
                              final plan = c['license_plan'] as String?;
                              final cycle = c['license_cycle'] as String?;
                              final liConnected = c['linkedin_connected'] as bool? ?? false;
                              final createdAt = c['created_at'] != null ? DateTime.tryParse(c['created_at'] as String) : null;
                              final isProcessing = _processingUserIds.contains(id);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: !isApproved ? Colors.amber.shade300 : Colors.grey.shade200,
                                    width: !isApproved ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: !isApproved
                                                ? Colors.amber.shade100
                                                : blue.withValues(alpha: 0.1),
                                            child: Icon(
                                              !isApproved ? Icons.hourglass_top_rounded : Icons.person,
                                              color: !isApproved ? Colors.amber.shade900 : blue,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                Text('ID: $id', style: const TextStyle(color: Colors.black45, fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                          // Approval Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isApproved ? Colors.green.shade50 : Colors.amber.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isApproved ? Colors.green.shade200 : Colors.amber.shade300,
                                              ),
                                            ),
                                            child: Text(
                                              isApproved ? 'APPROVED' : 'PENDING',
                                              style: TextStyle(
                                                color: isApproved ? Colors.green.shade800 : Colors.amber.shade900,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: hasLic ? Colors.green.shade100 : Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              hasLic ? 'ACTIVE: ${plan?.toUpperCase() ?? "STANDARD"} ($cycle)' : 'NO ACTIVE LICENSE',
                                              style: TextStyle(
                                                color: hasLic ? Colors.green.shade900 : Colors.black54,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: liConnected ? Colors.blue.shade100 : Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              liConnected ? 'LINKEDIN CONNECTED' : 'NO LINKEDIN',
                                              style: TextStyle(
                                                color: liConnected ? Colors.blue.shade900 : Colors.black54,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          if (createdAt != null)
                                            Text(
                                              DateFormat('yyyy-MM-dd').format(createdAt),
                                              style: const TextStyle(fontSize: 11, color: Colors.black45),
                                            ),
                                        ],
                                      ),

                                      // Approval Actions Row
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (!isApproved) ...[
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red.shade700,
                                                side: BorderSide(color: Colors.red.shade300),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              onPressed: isProcessing ? null : () => _rejectCustomer(id, email),
                                              icon: const Icon(Icons.close, size: 16),
                                              label: const Text('Reject', style: TextStyle(fontSize: 12)),
                                            ),
                                            const SizedBox(width: 8),
                                            FilledButton.icon(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: const Color(0xFF10B981),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              onPressed: isProcessing ? null : () => _approveCustomer(id, email),
                                              icon: isProcessing
                                                  ? const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                    )
                                                  : const Icon(Icons.check, size: 16),
                                              label: const Text('Approve Access', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            ),
                                          ] else ...[
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red.shade700,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              onPressed: isProcessing ? null : () => _rejectCustomer(id, email),
                                              icon: const Icon(Icons.block, size: 14),
                                              label: const Text('Revoke / Reject', style: TextStyle(fontSize: 11)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    bool isHighlight = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isHighlight ? Colors.amber.shade700 : const Color(0xFF14213D))
              : (isHighlight ? Colors.amber.shade50 : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isHighlight ? Colors.amber.shade400 : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isHighlight ? Colors.amber.shade900 : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
