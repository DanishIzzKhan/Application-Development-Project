// Test entry point for the owner screens. Does not replace main.dart.
// Run with:  flutter run -t lib/main_owner.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/owner_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(MaterialApp(
    title: 'ISYGEAR Owner (test)',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: const OwnerShell(),
  ));
}
