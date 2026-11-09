import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/sync_service.dart';
import '../services/secure_storage_service.dart';
import 'post_editor_screen.dart';

class AIGeneratorScreen extends StatefulWidget {
  final ApiClient apiClient;
  final SyncService syncService;

  const AIGeneratorScreen({
    super.key,
    required this.apiClient,
    required this.syncService,
  });

  @override
  State<AIGeneratorScreen> createState() => _AIGeneratorScreenState();
}

class _AIGeneratorScreenState extends State<AIGeneratorScreen> {
  final List<String> _topics = [
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

  late String _selectedTopic;
  final TextEditingController _customTopicController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  String? _generatedContent;
  bool _isGenerating = false;
  bool _isRegenerating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedTopic = _topics[0];
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferred = await SecureStorageService.instance.getPreferredTopics();
    if (preferred.isNotEmpty && mounted) {
      setState(() {
        for (final p in preferred.reversed) {
          _topics.remove(p);
          _topics.insert(0, p);
        }
        _selectedTopic = _topics[0];
      });
    }
  }

  String get _effectiveTopic {
    final custom = _customTopicController.text.trim();
    return custom.isNotEmpty ? custom : _selectedTopic;
  }

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final content = await widget.apiClient.generateAIPost(_effectiveTopic);
      if (!mounted) return;
      setState(() {
        _generatedContent = content;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Generation failed: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _regenerate() async {
    if (_generatedContent == null) return;
    setState(() {
      _isRegenerating = true;
      _errorMessage = null;
    });

    try {
      final instructions = _instructionsController.text.trim().isNotEmpty
          ? _instructionsController.text.trim()
          : null;
      final content = await widget.apiClient.regenerateAIPost(
        _generatedContent!,
        _effectiveTopic,
        instructions,
      );
      if (!mounted) return;
      setState(() {
        _generatedContent = content;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post successfully regenerated and refined.')),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Regeneration failed: $e');
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  void _proceedToEditor() {
    if (_generatedContent == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostEditorScreen(
          apiClient: widget.apiClient,
          syncService: widget.syncService,
          initialBody: _generatedContent!,
          initialTopic: _effectiveTopic,
          initialTitle: 'Cybersecurity Insight: $_effectiveTopic',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const ink = Color(0xFF14213D);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('AI Content Studio', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0,
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
                    const Text('Cybersecurity Domain',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ink)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTopic,
                      items: _topics.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedTopic = v);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Custom Focus / Angle (Optional)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _customTopicController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Active Directory kerberoasting mitigations',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _isGenerating ? null : _generate,
                        icon: _isGenerating
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome),
                        label: Text(_isGenerating ? 'Synthesizing with Gemini...' : 'Generate Cybersecurity Post'),
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

            if (_generatedContent != null) ...[
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.blue.shade200),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.article, color: blue, size: 20),
                              SizedBox(width: 6),
                              Text('Generated Post Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              '${_generatedContent!.split(RegExp(r'\s+')).length} words',
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      SelectableText(
                        _generatedContent!,
                        style: const TextStyle(fontSize: 13, height: 1.5, color: ink),
                      ),
                      const SizedBox(height: 16),

                      // Refinement options
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Refine / Adjust Tone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: blue)),
                        children: [
                          TextField(
                            controller: _instructionsController,
                            decoration: InputDecoration(
                              hintText: 'e.g., Shorten to 140 words, add more focus on SIEM alerts',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isRegenerating ? null : _regenerate,
                              icon: _isRegenerating
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.refresh, size: 16),
                              label: Text(_isRegenerating ? 'Regenerating...' : 'Apply Adjustments & Regenerate'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _proceedToEditor,
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Edit & Schedule Post'),
                              style: FilledButton.styleFrom(
                                backgroundColor: blue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
