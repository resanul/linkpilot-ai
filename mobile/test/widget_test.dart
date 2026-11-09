import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linkedin_ai_automation/services/api_client.dart';
import 'package:linkedin_ai_automation/services/sync_service.dart';
import 'package:linkedin_ai_automation/screens/login_screen.dart';
import 'package:linkedin_ai_automation/screens/license_activation_screen.dart';
import 'package:linkedin_ai_automation/screens/ai_generator_screen.dart';
import 'package:linkedin_ai_automation/screens/post_editor_screen.dart';
import 'package:linkedin_ai_automation/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'read') {
          return null;
        }
        if (methodCall.method == 'write') {
          return null;
        }
        return null;
      },
    );
  });

  testWidgets('LoginScreen renders Google Sign-In and QA buttons', (WidgetTester tester) async {
    final client = ApiClient(baseUrl: 'http://127.0.0.1:8000');
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(apiClient: client),
      ),
    );
    await tester.pump();

    expect(find.text('Welcome to LinkPilot AI'), findsOneWidget);
    expect(find.text('Sign In with Google'), findsOneWidget);
    expect(find.text('Sign in as Super Admin'), findsOneWidget);
    expect(find.text('Sign in as Customer'), findsOneWidget);
  });

  testWidgets('LicenseActivationScreen renders key input and guidance', (WidgetTester tester) async {
    final client = ApiClient(baseUrl: 'http://127.0.0.1:8000');
    final dummyUser = UserModel(
      id: 'u-123',
      email: 'testuser@example.com',
      role: 'user',
      hasActiveLicense: false,
      linkedinConnected: false,
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LicenseActivationScreen(apiClient: client, user: dummyUser),
      ),
    );
    await tester.pump();

    expect(find.text('Activate LinkPilot License'), findsOneWidget);
    expect(find.text('Logged in as testuser@example.com'), findsOneWidget);
    expect(find.text('Activate License'), findsOneWidget);
  });

  testWidgets('AIGeneratorScreen renders cybersecurity domains', (WidgetTester tester) async {
    final client = ApiClient(baseUrl: 'http://127.0.0.1:8000');
    final syncService = SyncService(apiClient: client);

    await tester.pumpWidget(
      MaterialApp(
        home: AIGeneratorScreen(apiClient: client, syncService: syncService),
      ),
    );
    await tester.pump();

    expect(find.text('AI Content Studio'), findsOneWidget);
    expect(find.text('Cybersecurity Domain'), findsOneWidget);
    expect(find.text('Generate Cybersecurity Post'), findsOneWidget);
  });

  testWidgets('PostEditorScreen renders form fields and character counter', (WidgetTester tester) async {
    final client = ApiClient(baseUrl: 'http://127.0.0.1:8000');
    final syncService = SyncService(apiClient: client);

    await tester.pumpWidget(
      MaterialApp(
        home: PostEditorScreen(
          apiClient: client,
          syncService: syncService,
          initialTitle: 'Test Post',
          initialBody: 'Testing post editor workflow',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Compose Post'), findsOneWidget);
    expect(find.text('Save Post'), findsOneWidget);
    expect(find.text('Require Manual Approval'), findsOneWidget);
  });
}
