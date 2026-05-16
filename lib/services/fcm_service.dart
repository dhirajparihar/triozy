import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


// === Push notifications ======================================================

/// Top-level handler required for background message processing.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

/// Wraps Firebase Cloud Messaging setup and local notifications.
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _badgeCount = 0;

  /// Initializes FCM handlers, permissions, and token persistence.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      await _setupLocalNotifications();
      await _requestPermissions();

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('FCM onMessageOpenedApp: ${message.messageId}');
      });

      await _persistTokenForCurrentUser();
      _messaging.onTokenRefresh.listen(_persistTokenForCurrentUserByToken);
      _initialized = true;
    } catch (e) {
      debugPrint('FCM initialize failed: $e');
    }
  }

  /// Sets up local notification channels and click handlers.
  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    const channel = AndroidNotificationChannel(
      'triozy_chat',
      'Chat Notifications',
      description: 'Message notifications',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Requests notification permissions and foreground display options.
  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (!kIsWeb) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Handles foreground messages by showing a local notification.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? 'New message';
    final body = message.notification?.body ?? 'You received a new message';
    await showLocalNotification(
      title: title,
      body: body,
      payload: message.data['conversationId']?.toString(),
    );
  }

  /// Persists the current FCM token to the signed-in user doc.
  Future<void> _persistTokenForCurrentUser() async {
    final token = await _messaging.getToken();
    if (token == null) {
      return;
    }
    await _persistTokenForCurrentUserByToken(token);
  }

  /// Persists a specific token for the signed-in user.
  Future<void> _persistTokenForCurrentUserByToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to persist FCM token: $e');
    }
  }

  /// Placeholder for server-side notification dispatch.
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint(
      'sendNotificationToUser is server-side responsibility. target=$userId title=$title body=$body payload=$payload',
    );
  }

  /// Displays a local notification and increments the badge count.
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    _badgeCount += 1;

    const android = AndroidNotificationDetails(
      'triozy_chat',
      'Chat Notifications',
      channelDescription: 'Message notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    final ios = DarwinNotificationDetails(
      badgeNumber: _badgeCount,
      presentBadge: true,
      presentAlert: true,
      presentSound: true,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );
  }
}
