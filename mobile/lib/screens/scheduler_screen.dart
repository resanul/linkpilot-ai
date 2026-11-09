import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../services/api_client.dart';
import '../services/sync_service.dart';

class SchedulerScreen extends StatefulWidget {
  final ApiClient apiClient;
  final SyncService syncService;

  const SchedulerScreen({
    super.key,
    required this.apiClient,
    required this.syncService,
  });

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  List<PostModel> _scheduledPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScheduledPosts();
  }

  Future<void> _loadScheduledPosts() async {
    setState(() => _isLoading = true);
    try {
      await widget.syncService.synchronize();
      final all = await widget.syncService.dbService.getAllPosts();
      if (!mounted) return;
      setState(() {
        _scheduledPosts = all.where((p) => p.status == 'scheduled').toList();
      });
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const ink = Color(0xFF14213D);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Publishing Scheduler', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadScheduledPosts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadScheduledPosts,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time_filled, color: Colors.amber, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'AUTOMATED DISPATCH ENGINE',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Daily 20:00 Asia/Dhaka',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Background worker executes publishing jobs at 8:00 PM Dhaka time and on 1-minute intervals for due posts.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Upcoming Scheduled Posts',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ink),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          '${_scheduledPosts.length} queued',
                          style: const TextStyle(color: blue, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_scheduledPosts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.black26, size: 40),
                            SizedBox(height: 12),
                            Text(
                              'No Posts Scheduled',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Approved posts or scheduled drafts will appear here.',
                              style: TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._scheduledPosts.map((post) => Card(
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
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'SCHEDULED',
                                        style: TextStyle(
                                          color: Colors.blue.shade900,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.timer_outlined, size: 14, color: Colors.black54),
                                    const SizedBox(width: 4),
                                    Text(
                                      post.scheduledAt != null
                                          ? DateFormat('MMM d · hh:mm a').format(post.scheduledAt!)
                                          : 'Immediate',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: blue),
                                    ),
                                  ],
                                ),
                                if (post.title != null) ...[
                                  const SizedBox(height: 8),
                                  Text(post.title!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  post.body,
                                  style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
