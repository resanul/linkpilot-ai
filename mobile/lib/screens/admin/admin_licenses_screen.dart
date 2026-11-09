import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/license_model.dart';
import '../../services/api_client.dart';

class AdminLicensesScreen extends StatefulWidget {
  final ApiClient apiClient;

  const AdminLicensesScreen({super.key, required this.apiClient});

  @override
  State<AdminLicensesScreen> createState() => _AdminLicensesScreenState();
}

class _AdminLicensesScreenState extends State<AdminLicensesScreen> {
  List<LicenseModel> _licenses = [];
  bool _isLoading = true;
  String _selectedPlan = 'enterprise';
  int _selectedDays = 30;
  bool _isGenerating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLicenses();
  }

  Future<void> _loadLicenses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await widget.apiClient.getAdminLicenses();
      if (!mounted) return;
      setState(() => _licenses = list);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load licenses: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createLicense() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final cycle = _selectedDays == 0 ? 'lifetime' : '${_selectedDays}_days';
      final res = await widget.apiClient.createAdminLicense(
        _selectedPlan,
        cycle,
        days: _selectedDays > 0 ? _selectedDays : null,
      );
      await _loadLicenses();
      if (!mounted) return;

      final key = res['license_key'] as String;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('License Generated'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plan: ${res["plan"].toString().toUpperCase()} · ${_selectedDays > 0 ? "$_selectedDays Days Validity" : "Lifetime"}'),
              const SizedBox(height: 12),
              const Text(
                'Copy and deliver this key securely to the customer. It cannot be retrieved again:',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  key,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: key));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('License key copied to clipboard!')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Key'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to generate license: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _revokeLicense(LicenseModel lic) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke License?'),
        content: Text('Are you sure you want to deactivate license ${lic.id}? The customer will immediately lose access to AI and publishing features.'),
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
      await widget.apiClient.revokeAdminLicense(lic.id);
      await _loadLicenses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('License revoked successfully.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const ink = Color(0xFF14213D);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('License Provisioning', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0,
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _loadLicenses),
        ],
      ),
      body: SingleChildScrollView(
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

            // License issuance card
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
                    const Text('Issue Commercial License',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ink)),
                    const SizedBox(height: 12),
                    const Text('Subscription Tier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPlan,
                      items: const [
                        DropdownMenuItem(value: 'enterprise', child: Text('Enterprise Tier')),
                        DropdownMenuItem(value: 'pro', child: Text('Pro Tier')),
                        DropdownMenuItem(value: 'standard', child: Text('Standard Tier')),
                        DropdownMenuItem(value: 'business', child: Text('Business Tier')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedPlan = v);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Active Duration / Validity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedDays,
                      items: const [
                        DropdownMenuItem(value: 30, child: Text('30 Days (Standard 1 Month)')),
                        DropdownMenuItem(value: 60, child: Text('60 Days (2 Months)')),
                        DropdownMenuItem(value: 90, child: Text('90 Days (Quarterly)')),
                        DropdownMenuItem(value: 180, child: Text('180 Days (Half Year)')),
                        DropdownMenuItem(value: 365, child: Text('365 Days (Enterprise 1 Year)')),
                        DropdownMenuItem(value: 0, child: Text('Lifetime (Permanent / No Expiry)')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedDays = v);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _isGenerating ? null : _createLicense,
                        icon: _isGenerating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add_card),
                        label: Text(_isGenerating ? 'Provisioning...' : 'Generate License Key'),
                        style: FilledButton.styleFrom(
                          backgroundColor: blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Provisioned Licenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ink)),
                Text('${_licenses.length} total', style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_licenses.isEmpty)
              const Center(child: Text('No licenses issued yet.'))
            else
              ..._licenses.map((lic) {
                final isExpired = lic.expiresAt != null && lic.expiresAt!.isBefore(DateTime.now());
                final statusText = !lic.active ? 'REVOKED' : (isExpired ? 'EXPIRED' : (lic.assigned ? 'ASSIGNED' : 'UNASSIGNED'));
                final statusColor = !lic.active ? Colors.red : (isExpired ? Colors.orange : (lic.assigned ? Colors.green : blue));

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${lic.plan.toUpperCase()} · ${lic.billingCycle.replaceAll("_", " ").toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const Spacer(),
                            if (lic.active)
                              IconButton(
                                tooltip: 'Revoke License',
                                icon: const Icon(Icons.block, color: Colors.red, size: 18),
                                onPressed: () => _revokeLicense(lic),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('ID: ${lic.id}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text(
                          lic.expiresAt != null
                              ? 'Expires: ${DateFormat('yyyy-MM-dd').format(lic.expiresAt!)}'
                              : 'Expires: Never (Lifetime)',
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
