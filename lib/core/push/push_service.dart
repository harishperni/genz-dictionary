import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class PushService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'genz_daily_channel';
  static const String _channelName = 'GenZ Daily Nudges';
  static const String _channelDesc = 'Daily streak reminders and updates';

  static StreamSubscription<RemoteMessage>? _fgSub;
  static StreamSubscription<RemoteMessage>? _openedSub;

  static void Function(RemoteMessage message)? _onOpenedCallback;

  static bool _didInit = false;
  static bool _tzReady = false;

  // -------------------- PUBLIC API --------------------

  /// Idempotent init — safe to call multiple times.
  static Future<void> init() async {
    if (_didInit) return;
    _didInit = true;

    final sw = Stopwatch()..start();

    // 1) Local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _fln.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        debugPrint('🔔 Local notification tapped: ${resp.payload}');
      },
    );

    // Create notification channel once
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Android 13+ runtime notification permission
    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // 2) FCM permissions + token
    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    final token = await _fcm.getToken();
    debugPrint('🔑 FCM token: $token');

    // 3) Foreground listener → show banner
    _fgSub?.cancel();
    _fgSub = FirebaseMessaging.onMessage.listen((m) async {
      final n = m.notification;
      debugPrint(
          '📨 [FG] id=${m.messageId} title=${n?.title} body=${n?.body} data=${m.data}');
      await showForegroundNotification(m);
    });

    // 4) Notification tap listener
    _openedSub?.cancel();
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((m) {
      debugPrint('🚪 [OPENED] data=${m.data}');
      _onOpenedCallback?.call(m);
    });

    // 5) Schedule daily nudge lazily (don’t block init)
    Future<void>(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      await ensureDailyNudgeScheduledOnce();
    });

    debugPrint('⚙️ PushService.init in ${sw.elapsedMilliseconds}ms');
  }

  static Future<RemoteMessage?> getInitialMessage() =>
      _fcm.getInitialMessage();

  static void onOpened(void Function(RemoteMessage message) cb) {
    _onOpenedCallback = cb;
  }

  // -------------------- NOTIFICATIONS --------------------

  static Future<void> showForegroundNotification(RemoteMessage m) async {
    final n = m.notification;
    final title = n?.title ?? 'Gen Z Dictionary';
    final body = n?.body ?? 'Open to check today’s slang!';

    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const details = NotificationDetails(android: android);

    await _fln.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1000000),
      title,
      body,
      details,
      payload: _encodeSimplePayload(m.data),
    );
  }

  /// Schedules 8 PM local nudge once; safe to call repeatedly.
  static Future<void> ensureDailyNudgeScheduledOnce() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'daily_nudge_scheduled_v1';
    if (prefs.getBool(key) == true) return;

    await _lazyInitTimezone();
    await scheduleDailyNudge(); // schedules from "now" to next 8 PM
    await prefs.setBool(key, true);
  }

  /// Schedules a daily 8 PM nudge (call via ensureDailyNudgeScheduledOnce()).
  static Future<void> scheduleDailyNudge({
    TimeOfDay at = const TimeOfDay(hour: 20, minute: 0),
    String title = 'Keep your streak 🔥',
    String body = 'Open Gen Z Dictionary to keep your streak alive!',
  }) async {
    await _lazyInitTimezone();

    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime first = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      at.hour,
      at.minute,
    );
    if (first.isBefore(now)) {
      first = first.add(const Duration(days: 1));
    }

    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const details = NotificationDetails(android: android);

    // ✅ Request exact-alarm permission on Android 12+
    final androidImpl = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    bool canSchedule = true;
    try {
      canSchedule = await androidImpl?.requestExactAlarmsPermission() ?? true;
    } catch (e) {
      debugPrint('⚠️ Exact-alarm permission check failed: $e');
    }

    if (canSchedule) {
      await _fln.zonedSchedule(
        8000,
        title,
        body,
        first,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('⏰ Daily nudge scheduled for ${at.hour}:${at.minute}');
    } else {
      // 🚑 Fallback for denied permission
      debugPrint('⚠️ Exact alarms not permitted — using periodic reminder.');
      await _fln.periodicallyShow(
        8001,
        title,
        body,
        RepeatInterval.daily,
        details,
        androidAllowWhileIdle: true,
      );
    }
  }

  /// One-off local test to confirm channel works.
  static Future<void> testLocal() async {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const details = NotificationDetails(android: android);
    await _fln.show(
      9997,
      'Local Test ✅',
      'This proves the channel works.',
      details,
    );
  }

  // -------------------- HELPERS --------------------

  static Future<void> _lazyInitTimezone() async {
    if (_tzReady) return;
    final sw = Stopwatch()..start();
    tzdata.initializeTimeZones(); // heavy; do once
    final now = DateTime.now();
    try {
      tz.setLocalLocation(tz.getLocation(now.timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    _tzReady = true;
    debugPrint('🕒 tz init in ${sw.elapsedMilliseconds} ms');
  }

  static String? _encodeSimplePayload(Map<String, dynamic> data) {
    if (data.isEmpty) return null;
    try {
      return data.entries.map((e) => '${e.key}=${e.value}').join('&');
    } catch (_) {
      return null;
    }
  }
}