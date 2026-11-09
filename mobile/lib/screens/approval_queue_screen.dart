import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../services/api_client.dart';
import '../services/sync_service.dart';
import 'post_editor_screen.dart';

class ApprovalQueueScreen extends StatefulWidget {
  final ApiClient apiClient;
  final SyncService syncService;

  const ApprovalQueueScreen({
    super.key,
    required this.apiClient,
    required this.syncService,
  });

  @override
  State<ApprovalQueueScreen> createState() => _ApprovalQueueScreenState();
}

class _ApprovalQueueScreenState extends State<ApprovalQueueScreen> {
  List<PostModel> _pendingPosts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingPosts();
  }

  Future<void> _loadPendingPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Sync latest from backend
      await widget.syncService.synchronize();
      final all = await widget.syncService.dbService.getAllPosts();
      if (!mounted) return;
      setState(() {
        _pendingPosts = all.where((p) => p.status == 'pending_approval').toList();
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load approval queue: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approvePost(PostModel post) async {
    try {
      final res = await widget.apiClient.approvePost(post.id);
      final updated = post.copyWith(
        status: 'scheduled',
        scheduledAt: res['scheduled_at'] != null ? DateTime.tryParse(res['scheduled_at'] as String) : DateTime.now(),
      );
      await widget.syncService.dbService.insertOrUpdatePost(updated);
      await _loadPendingPosts();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post approved and scheduled for publishing!'), backgroundColor: Colors.green),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approval error: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approval error: $e')));
    }
  }

  Future<void> _rejectPost(PostModel post) async {
    try {
      await widget.apiClient.rejectPost(post.id);
      final updated = post.copyWith(status: 'rejected');
      await widget.syncService.dbService.insertOrUpdatePost(updated);
      await _loadPendingPosts();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post rejected.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reject error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const ink = Color(0xFF14213D);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Approval Queue', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingPosts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPendingPosts,
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
                    child: _pendingPosts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.done_all, size: 56, color: Colors.green.shade400),
                                const SizedBox(height: 16),
                                const Text(
                                  'Queue is Clear',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ink),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'No cybersecurity posts currently awaiting approval.',
                                  style: TextStyle(color: Colors.black54, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _pendingPosts.length,
                            itemBuilder: (context, index) {
                              final post = _pendingPosts[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
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
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'AWAITING APPROVAL',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                                color: Colors.amber.shade900,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            DateFormat('MMM d, hh:mm a').format(post.createdAt),
                                            style: const TextStyle(fontSize: 11, color: Colors.black45),
                                          ),
                                        ],
                                      ),
                                      if (post.title != null && post.title!.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          post.title!,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                      ],
                                      if (post.topic != null && post.topic!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Topic: ${post.topic!}',
                                          style: const TextStyle(fontSize: 12, color: blue, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Text(
                                        post.body,
                                        style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                                        maxLines: 5,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              final res = await Navigator.of(context).push<bool>(
                                                MaterialPageRoute(
                                                  builder: (_) => PostEditorScreen(
                                                    apiClient: widget.apiClient,
                                                    syncService: widget.syncService,
                                                    existingPost: post,
                                                  ),
                                                ),
                                              );
                                              if (res == true) _loadPendingPosts();
                                            },
                                            icon: const Icon(Icons.edit, size: 16),
                                            label: const Text('Edit'),
                                          ),
                                          const Spacer(),
                                          TextButton(
                                            onPressed: () => _rejectPost(post),
                                            child: const Text('Reject', style: TextStyle(color: Colors.red)),
                                          ),
                                          const SizedBox(width: 8),
                                          FilledButton.icon(
                                            onPressed: () => _approvePost(post),
                                            icon: const Icon(Icons.check, size: 16),
                                            label: const Text('Approve'),
                                            style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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
