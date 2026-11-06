import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/c1_login.dart';
import 'screens/c3_vehicles.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const IsygearApp());
}

class IsygearApp extends StatelessWidget {
  const IsygearApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Returning customers who are still signed in go straight to C3.
    final signedIn = Supabase.instance.client.auth.currentSession != null;
    return MaterialApp(
      title: 'ISYGEAR Rentals',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: signedIn ? const VehiclesScreen() : const LoginScreen(),
    );
  }
}