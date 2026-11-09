import 'dart:convert';
import 'package:http/http.dart' as http;

class ProjectEngine {
  static final ProjectEngine instance = ProjectEngine._internal();
  ProjectEngine._internal();

  /// Direct Google Gemini API generation from mobile device (Serverless)
  Future<String> generateGeminiDirect({
    required String topic,
    required String apiKey,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    final prompt = '''
You are a Principal Cybersecurity Architect and influential LinkedIn thought leader.
Write a compelling, professional, and practical LinkedIn post focused on:

Topic: $topic

Requirements:
1. Hook: Start with a powerful 1-2 sentence opening hook that grabs cybersecurity professionals (CISOs, SOC leads, SecOps engineers).
2. The Challenge: Briefly explain the core practical problem or emerging risk in 2-3 sentences.
3. Actionable Insights: Provide 3-4 concise, bulleted technical takeaways, architectural recommendations, or actionable triage steps (use clean emojis or dashes).
4. Engagement Question: End with an open-ended question inviting peers and community members to share their perspectives.
5. Hashtags: End with 4-5 relevant hashtags (include #CyberSecurity #InfoSec).
6. Tone: Authoritative, pragmatic, no fluff. Keep length between 800 and 1,300 characters.

Format directly as plain text for LinkedIn.
''';

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1000,
      }
    };

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map<String, dynamic>;
        final parts = content['parts'] as List<dynamic>;
        if (parts.isNotEmpty) {
          final rawText = parts[0]['text'] as String;
          return rawText.replaceAll('```markdown', '').replaceAll('```', '').trim();
        }
      }
    }

    throw Exception('Gemini API call returned status ${res.statusCode}: ${res.body}');
  }

  /// High-quality built-in cybersecurity post generator when no API key is supplied
  String generateTemplatePost(String topic) {
    return '''🚨 Why $topic is making or breaking modern enterprise security:

Too many security operations teams still treat this as an afterthought until an active adversary exposes the gap. Here is what separates mature security programs from reactive ones:

🔹 Context Over Volume: Telemetry without contextual asset classification leads straight to alert fatigue and missed pivots.
🔹 Shift From Indicators to Behaviors: IOCs expire in hours; adversary TTPs mapped to MITRE ATT&CK persist across campaigns.
🔹 Continuous Validation: If your detection or prevention controls aren't validated against simulated attacks weekly, assume they don't work.
🔹 Clear Escalation Playbooks: Speed of containment dictates the eventual breach blast radius.

What is the biggest operational hurdle your team faces with $topic today?

Share your thoughts in the comments! 👇

#CyberSecurity #InfoSec #BlueTeam #SOC #CloudSecurity''';
  }

  /// Direct LinkedIn API publishing from mobile device (Serverless)
  Future<Map<String, dynamic>> publishLinkedInDirect({
    required String content,
    required String token,
  }) async {
    // 1. Resolve author URN
    final userinfoUri = Uri.parse('https://api.linkedin.com/v2/userinfo');
    final userinfoRes = await http.get(
      userinfoUri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    String? authorUrn;
    String profileName = 'LinkedIn Member';

    if (userinfoRes.statusCode == 200) {
      final info = jsonDecode(userinfoRes.body) as Map<String, dynamic>;
      final sub = info['sub'] as String?;
      profileName = (info['name'] as String?) ?? profileName;
      if (sub != null) {
        authorUrn = 'urn:li:person:$sub';
      }
    }

    if (authorUrn == null) {
      // Fallback to /v2/me
      final meUri = Uri.parse('https://api.linkedin.com/v2/me');
      final meRes = await http.get(
        meUri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (meRes.statusCode == 200) {
        final me = jsonDecode(meRes.body) as Map<String, dynamic>;
        final id = me['id'] as String?;
        final first = me['localizedFirstName'] ?? '';
        final last = me['localizedLastName'] ?? '';
        profileName = '$first $last'.trim();
        if (id != null) {
          authorUrn = 'urn:li:person:$id';
        }
      }
    }

    if (authorUrn == null) {
      throw Exception('Could not verify LinkedIn profile with the provided access token.');
    }

    // 2. Publish post via LinkedIn REST Posts API
    final restUri = Uri.parse('https://api.linkedin.com/rest/posts');
    final payload = {
      'author': authorUrn,
      'commentary': content,
      'visibility': 'PUBLIC',
      'distribution': {
        'feedDistribution': 'MAIN_FEED',
        'targetEntities': [],
        'thirdPartyDistributionChannels': [],
      },
      'lifecycleState': 'PUBLISHED',
      'isReshareDisabledByAuthor': false,
    };

    final postRes = await http.post(
      restUri,
      headers: {
        'Authorization': 'Bearer $token',
        'LinkedIn-Version': '202401',
        'X-Restli-Protocol-Version': '2.0.0',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 25));

    if (postRes.statusCode == 201 || postRes.statusCode == 200) {
      final postId = postRes.headers['x-restli-id'] ?? 'urn:li:share:published';
      return {
        'success': true,
        'post_id': postId,
        'profile_name': profileName,
      };
    }

    // Fallback: UGC Posts API
    final ugcUri = Uri.parse('https://api.linkedin.com/v2/ugcPosts');
    final ugcPayload = {
      'author': authorUrn,
      'lifecycleState': 'PUBLISHED',
      'specificContent': {
        'com.linkedin.ugc.ShareContent': {
          'shareCommentary': {'text': content},
          'shareMediaCategory': 'NONE',
        }
      },
      'visibility': {'com.linkedin.ugc.MemberNetworkVisibility': 'PUBLIC'},
    };

    final ugcRes = await http.post(
      ugcUri,
      headers: {
        'Authorization': 'Bearer $token',
        'X-Restli-Protocol-Version': '2.0.0',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(ugcPayload),
    ).timeout(const Duration(seconds: 25));

    if (ugcRes.statusCode == 201 || ugcRes.statusCode == 200) {
      final data = jsonDecode(ugcRes.body) as Map<String, dynamic>;
      return {
        'success': true,
        'post_id': data['id'] ?? 'urn:li:share:published',
        'profile_name': profileName,
      };
    }

    throw Exception('LinkedIn publishing failed (${ugcRes.statusCode}): ${ugcRes.body}');
  }

  /// Trigger GitHub Actions daily post workflow from phone
  Future<bool> triggerGitHubActions({
    required String repo,
    required String token,
    String? topic,
    bool dryRun = false,
  }) async {
    final uri = Uri.parse('https://api.github.com/repos/$repo/actions/workflows/daily_post.yml/dispatches');
    final payload = {
      'ref': 'main',
      'inputs': {
        'domain': topic ?? 'auto',
        'dry_run': dryRun.toString(),
      }
    };

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));

    return res.statusCode == 204 || res.statusCode == 200;
  }
}
