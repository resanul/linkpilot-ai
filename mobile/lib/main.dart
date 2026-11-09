import 'package:flutter/material.dart';
import 'services/api_client.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = ApiClient();
  runApp(LinkPilotApp(apiClient: apiClient));
}

class LinkPilotApp extends StatelessWidget {
  final ApiClient apiClient;

  const LinkPilotApp({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const ink = Color(0xFF14213D);
    const canvas = Color(0xFFF4F6FA);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LinkPilot AI',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          primary: blue,
          secondary: ink,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: SplashScreen(apiClient: apiClient),
    );
  }
}
