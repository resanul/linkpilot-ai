import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../services/api_client.dart';
import '../services/sync_service.dart';

class PostEditorScreen extends StatefulWidget {
  final ApiClient apiClient;
  final SyncService syncService;
  final PostModel? existingPost;
  final String? initialBody;
  final String? initialTitle;
  final String? initialTopic;

  const PostEditorScreen({
    super.key,
    required this.apiClient,
    required this.syncService,
    this.existingPost,
    this.initialBody,
    this.initialTitle,
    this.initialTopic,
  });

  @override
  State<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends State<PostEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _topicController;
  late TextEditingController _bodyController;
  late bool _approvalRequired;
  DateTime? _scheduledAt;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final p = widget.existingPost;
    _titleController = TextEditingController(text: p?.title ?? widget.initialTitle ?? '');
    _topicController = TextEditingController(text: p?.topic ?? widget.initialTopic ?? 'Cybersecurity');
    _bodyController = TextEditingController(text: p?.body ?? widget.initialBody ?? '');
    _approvalRequired = p?.approvalRequired ?? true;
    _scheduledAt = p?.scheduledAt ?? _defaultDhakaScheduleTime();
  }

  DateTime _defaultDhakaScheduleTime() {
    final now = DateTime.now();
    DateTime target = DateTime(now.year, now.month, now.day, 20, 0);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  Future<void> _pickScheduleTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _scheduledAt?.hour ?? 20,
        minute: _scheduledAt?.minute ?? 0,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _savePost() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_approvalRequired && _scheduledAt == null) {
      setState(() => _errorMessage = 'A scheduled publishing time is required when manual approval is disabled.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (widget.existingPost != null) {
        // Update existing post
        final updated = await widget.apiClient.updatePost(
          widget.existingPost!.id,
          body: _bodyController.text.trim(),
          title: _titleController.text.trim(),
          topic: _topicController.text.trim(),
          approvalRequired: _approvalRequired,
          scheduledAt: _scheduledAt,
        );
        await widget.syncService.dbService.insertOrUpdatePost(updated);
      } else {
        // Create new post
        final created = await widget.apiClient.createPost(
          body: _bodyController.text.trim(),
          title: _titleController.text.trim(),
          topic: _topicController.text.trim(),
          approvalRequired: _approvalRequired,
          scheduledAt: _scheduledAt,
        );
        await widget.syncService.dbService.insertOrUpdatePost(created);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_approvalRequired ? 'Post saved to Approval Queue.' : 'Post scheduled for publishing.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const ink = Color(0xFF14213D);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(widget.existingPost != null ? 'Edit Post' : 'Compose Post',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _isSaving ? null : _savePost,
              style: FilledButton.styleFrom(backgroundColor: blue),
              child: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Post'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
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
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Post Title (Internal)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'e.g., SIEM Detection Engineering Best Practices',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Topic / Domain', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _topicController,
                        decoration: InputDecoration(
                          hintText: 'e.g., Incident Response, MITRE ATT&CK',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Post Content (LinkedIn)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          AnimatedBuilder(
                            animation: _bodyController,
                            builder: (context, _) => Text(
                              '${_bodyController.text.length}/3000 chars · ${_bodyController.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length} words',
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _bodyController,
                        maxLines: 8,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Content cannot be empty.';
                          if (v.trim().length > 3000) return 'Exceeds 3000 characters.';
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Write or paste your LinkedIn post in English...',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
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
                      const Text('Publishing & Approval Workflow',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ink)),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _approvalRequired,
                        title: const Text('Require Manual Approval', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text(
                          'When enabled, post stays in Approval Queue until explicitly approved before publishing.',
                          style: TextStyle(fontSize: 12),
                        ),
                        onChanged: (v) => setState(() => _approvalRequired = v),
                      ),
                      const Divider(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule, color: blue),
                        title: const Text('Scheduled Publishing Target', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          _scheduledAt != null
                              ? '${DateFormat('yyyy-MM-dd · hh:mm a').format(_scheduledAt!)} (Asia/Dhaka)'
                              : 'Immediate / Not scheduled',
                          style: const TextStyle(fontSize: 13, color: blue),
                        ),
                        trailing: OutlinedButton(
                          onPressed: _pickScheduleTime,
                          child: const Text('Change Time'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
