import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../services/api_client.dart';
import '../services/sync_service.dart';
import 'post_editor_screen.dart';

class HistoryScreen extends StatefulWidget {
  final ApiClient apiClient;
  final SyncService syncService;

  const HistoryScreen({
    super.key,
    required this.apiClient,
    required this.syncService,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<PostModel> _allPosts = [];
  String _selectedFilter = 'all';
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final posts = await widget.syncService.loadPosts();
      if (!mounted) return;
      setState(() => _allPosts = posts);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    final result = await widget.syncService.synchronize();
    final updated = await widget.syncService.dbService.getAllPosts();
    if (!mounted) return;
    setState(() {
      _allPosts = updated;
      _isSyncing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success
            ? 'Synced ${result.syncedCount} posts with cloud.'
            : 'Sync failed: ${result.errorMessage}'),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  List<PostModel> get _filteredPosts {
    if (_selectedFilter == 'all') return _allPosts;
    return _allPosts.where((p) => p.status == _selectedFilter).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
        return Colors.green;
      case 'scheduled':
        return const Color(0xFF2563EB);
      case 'pending_approval':
        return Colors.amber.shade800;
      case 'rejected':
        return Colors.grey.shade700;
      case 'failed':
        return Colors.red;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Post History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sync Cloud & Local',
            icon: _isSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncNow,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _filterChip('all', 'All (${_allPosts.length})'),
                      _filterChip('published', 'Published (${_allPosts.where((p) => p.status == 'published').length})'),
                      _filterChip('scheduled', 'Scheduled (${_allPosts.where((p) => p.status == 'scheduled').length})'),
                      _filterChip('pending_approval', 'Pending (${_allPosts.where((p) => p.status == 'pending_approval').length})'),
                      _filterChip('failed', 'Failed (${_allPosts.where((p) => p.status == 'failed').length})'),
                    ],
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _syncNow,
                    child: _filteredPosts.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history, size: 48, color: Colors.black26),
                                SizedBox(height: 12),
                                Text('No Posts in this Category',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                SizedBox(height: 4),
                                Text('Posts generated or synchronized will appear here.',
                                    style: TextStyle(color: Colors.black54, fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredPosts.length,
                            itemBuilder: (context, index) {
                              final post = _filteredPosts[index];
                              final statusColor = _statusColor(post.status);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
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
                                              color: statusColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              post.status.toUpperCase().replaceAll('_', ' '),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (!post.isSynced)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.cloud_off, size: 10, color: Colors.orange),
                                                  SizedBox(width: 4),
                                                  Text('OFFLINE', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          const Spacer(),
                                          Text(
                                            DateFormat('MMM d, yyyy').format(post.createdAt),
                                            style: const TextStyle(fontSize: 11, color: Colors.black45),
                                          ),
                                        ],
                                      ),
                                      if (post.title != null) ...[
                                        const SizedBox(height: 10),
                                        Text(post.title!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        post.body,
                                        style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),

                                      if (post.status == 'published' && post.linkedinPostId != null) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'LinkedIn Post ID: ${post.linkedinPostId}',
                                                  style: const TextStyle(fontSize: 11, color: Colors.green, fontFamily: 'monospace'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      if (post.status == 'failed' && post.errorMessage != null) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.error, size: 14, color: Colors.red),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  post.errorMessage!,
                                                  style: const TextStyle(fontSize: 11, color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            tooltip: 'Edit / View',
                                            icon: const Icon(Icons.edit_outlined, size: 18),
                                            onPressed: () async {
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => PostEditorScreen(
                                                    apiClient: widget.apiClient,
                                                    syncService: widget.syncService,
                                                    existingPost: post,
                                                  ),
                                                ),
                                              );
                                              _loadPosts();
                                            },
                                          ),
                                          IconButton(
                                            tooltip: 'Delete',
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                            onPressed: () async {
                                              await widget.syncService.dbService.deletePost(post.id);
                                              try {
                                                await widget.apiClient.deletePost(post.id);
                                              } catch (_) {}
                                              _loadPosts();
                                            },
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
                ),
              ],
            ),
    );
  }

  Widget _filterChip(String filter, String label) {
    final selected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: selected,
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        onSelected: (_) => setState(() => _selectedFilter = filter),
        selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
        checkmarkColor: const Color(0xFF2563EB),
      ),
    );
  }
}
