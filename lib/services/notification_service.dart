import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    
    const channel = AndroidNotificationChannel(
      'messages_channel',
      'Messages',
      description: 'اشعارات الرسائل',
      importance: Importance.high,
      playSound: true,
    );
    
    await _plugin
     .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
     ?.createNotificationChannel(channel);
  }

  Future<int> unreadCount(String uid) async {
    return 0;
  }

  Future<void> markAllRead(String uid) async {}

  Stream<List<NotificationModel>> userNotifications(String uid) async* {
    yield [];
  }

  Future<void> sendNotification(NotificationModel notification) async {}

  Future<void> showNotification(String title, String body) async {
    const android = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'اشعارات الرسائل',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: android),
    );
  }

  static Future<void> showMessageNotification({
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'اشعارات الرسائل',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: android),
    );
  }
}
