// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app.dart';
import 'core/push/push_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep minimal to avoid blocking/background crashes
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Required before using any Firebase services your home screen needs
  await Firebase.initializeApp();

  // Init local notifications + FCM foreground handling
  await PushService.init();

  // Wire FCM listeners (these don’t block UI)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen((RemoteMessage m) {
    // Show a local notification while app is in foreground
    PushService.showForegroundNotification(m);
  });
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
    // (Optional) route based on m.data later if you want
  });

  // Do NOT block first frame for scheduling; run it after the app paints
  // so splash screen doesn’t sit there forever.
  Future.microtask(() async {
    try {
      await PushService.ensureDailyNudgeScheduledOnce();
    } catch (_) {
      // swallow—scheduling can be retried later if needed
    }
  });

  runApp(const ProviderScope(child: GenZApp()));
}