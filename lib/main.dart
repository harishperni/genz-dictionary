// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';     // ✅ add this
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app.dart';
import 'core/push/push_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Minimal background setup
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase first
  await Firebase.initializeApp();

  // ✅ Ensure there's always a signed-in user (anonymous if needed)
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
    debugPrint('✅ Signed in anonymously as ${auth.currentUser!.uid}');
  }

  // ✅ Init notifications + FCM
  await PushService.init();

  // ✅ Wire up background and foreground message handling
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen((RemoteMessage m) {
    PushService.showForegroundNotification(m);
  });
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
    // optional: route handling later
  });

  // ✅ Schedule daily push reminder asynchronously
  Future.microtask(() async {
    try {
      await PushService.ensureDailyNudgeScheduledOnce();
    } catch (_) {
      // ignore errors silently
    }
  });

  // ✅ Finally run app
  runApp(const ProviderScope(child: GenZApp()));
}