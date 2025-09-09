import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'theme/app_theme.dart';
import 'app.dart';

// If you ran `flutterfire configure`, this file will exist:
import 'firebase_options.dart'; // <-- make sure this exists, see Step 2

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // uses firebase_options.dart
  );

  // Anonymous auth (needed for per-user data like streaks)
  await FirebaseAuth.instance.signInAnonymously();

  runApp(const ProviderScope(child: GenZApp()));
}

class GenZApp extends StatelessWidget {
  const GenZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Gen Z Dictionary',
      theme: buildTheme(),
      routerConfig: buildRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}