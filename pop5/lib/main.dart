import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/c1_login.dart';
import 'screens/c3_vehicles.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var signedIn = false;
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    signedIn = Supabase.instance.client.auth.currentSession != null;
  } catch (e) {
    // Wrong/missing URL or key: the UI still opens (see AppConfig.uiPreviewMode).
    debugPrint('Supabase could not start: $e');
  }

  runApp(IsygearApp(startSignedIn: signedIn));
}

class IsygearApp extends StatelessWidget {
  final bool startSignedIn;
  const IsygearApp({super.key, required this.startSignedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ISYGEAR Rentals',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: startSignedIn ? const VehiclesScreen() : const LoginScreen(),
    );
  }
}