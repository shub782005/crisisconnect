import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Background message handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.showLocalNotification(
    title: message.notification?.title ?? 'CrisisConnect',
    body:  message.notification?.body  ?? '',
  );
}

enum NotifType { urgent, warning, success, info }

class NotificationService {
  static final _fcm   = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'crisisconnect_high';
  static const _channelName = 'Crisis Alerts';
  static const _channelDesc = 'High-priority disaster relief notifications';

  // ── Init ─────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    await _fcm.requestPermission(
      alert: true, badge: true, sound: true, announcement: true);

    const androidChannel = AndroidNotificationChannel(
      _channelId, _channelName,
      description: _channelDesc,
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );
    await _local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _local.initialize(initSettings);

    FirebaseMessaging.onMessage.listen((msg) {
      if (msg.notification != null) {
        showLocalNotification(
          title: msg.notification!.title ?? 'CrisisConnect',
          body:  msg.notification!.body  ?? '',
          payload: msg.data['route'],
        );
      }
    });

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true);
  }

  // ── Token management ─────────────────────────────────────────────────────
  static Future<String?> getToken() async {
    try { return await _fcm.getToken(); } catch (_) { return null; }
  }

  static Future<void> saveTokenForUser(String uid) async {
    final token = await getToken();
    if (token == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fcmToken': token,
      'tokenUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> saveTokenForVolunteer(String uid) async {
    final token = await getToken();
    if (token == null) return;
    try {
      await FirebaseFirestore.instance
        .collection('volunteers').doc(uid)
        .update({'fcmToken': token});
    } catch (_) {}
  }

  // ── Show local notification ──────────────────────────────────────────────
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    NotifType type = NotifType.info,
  }) async {
    final color = _typeColor(type);
    final androidDetails = AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      color: color,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(body),
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true, presentBadge: true, presentSound: true);

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title, body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  // ── App-level notification triggers ─────────────────────────────────────
  static Future<void> notifyTaskAssigned({
    required String volunteerName,
    required String needType,
    required String urgencyLevel,
    required String location,
  }) async {
    await showLocalNotification(
      title: '🚨 New Task — ${urgencyLevel.toUpperCase()}',
      body:  'Hi $volunteerName! ${needType.toUpperCase()} need at $location requires your help.',
      payload: '/volunteer',
      type: urgencyLevel == 'high' ? NotifType.urgent : NotifType.info,
    );
  }

  static Future<void> notifyTaskCompleted({
    required String volunteerName,
    required String needType,
    required int peopleHelped,
  }) async {
    await showLocalNotification(
      title: '✅ Task Completed!',
      body:  '$volunteerName completed a $needType need — $peopleHelped people helped.',
      payload: '/admin',
      type: NotifType.success,
    );
  }

  static Future<void> broadcastCrisisAlert({
    required String needType,
    required String location,
    required int peopleAffected,
  }) async {
    await showLocalNotification(
      title: '⚠️ HIGH URGENCY: ${needType.toUpperCase()} Crisis',
      body:  '$peopleAffected people affected at $location. Volunteers needed immediately.',
      payload: '/map',
      type: NotifType.urgent,
    );
  }

  static Future<void> notifyTaskReminder({
    required String needType,
    required String location,
  }) async {
    await showLocalNotification(
      title: '⏰ Task Reminder',
      body:  'You still have a $needType task at $location. Please update your status.',
      payload: '/volunteer',
      type: NotifType.warning,
    );
  }

  // ── Topic subscriptions ──────────────────────────────────────────────────
  static Future<void> subscribeToAdminAlerts()     => _fcm.subscribeToTopic('admin_alerts');
  static Future<void> subscribeToVolunteerAlerts() => _fcm.subscribeToTopic('volunteer_alerts');
  static Future<void> subscribeToUrgentAlerts()    => _fcm.subscribeToTopic('urgent');

  // ── Color helper ─────────────────────────────────────────────────────────
  static Color _typeColor(NotifType type) {
    switch (type) {
      case NotifType.urgent:  return const Color(0xFFE53935);
      case NotifType.warning: return const Color(0xFFFB8C00);
      case NotifType.success: return const Color(0xFF43A047);
      case NotifType.info:    return const Color(0xFF1565C0);
    }
  }
}
