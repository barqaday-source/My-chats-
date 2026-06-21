import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final _plugin = FlutterLocalNotificationsPlugin();
  final _supabase = Supabase.instance.client;

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
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .or('user_id.eq.$uid,user_id.is.null')
          .eq('is_read', false);
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> markRead(String notificationId) async {
    await _supabase.from('notifications').update({'is_read': true}).eq('id', notificationId);
  }

  Future<void> markAllRead(String uid) async {
    try {
      // اشعاراتك الخاصة
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
      // اشعارات الادمن العامة ما نقدر نعلمها مقروءة للكل، 
      // إذا تريدها per-user لازم جدول notifications_read منفصل
    } catch (e) {
      print('markAllRead error: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    await _supabase.from('notifications').delete().eq('id', notificationId);
  }

  // هنا كان السبب
  Stream<List<NotificationModel>> userNotifications(String uid) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((maps) {
          // فلترة محلية: لي أو للكل
          final filtered = maps.where((m) => 
            m['user_id'] == null || m['user_id'] == uid
          ).toList();
          return filtered.map((map) => NotificationModel.fromJson(map)).toList();
        });
  }

  Future<void> sendNotification(NotificationModel notification) async {
    try {
      await _supabase.from('notifications').insert(notification.toJson());
      await showNotification(notification.title, notification.body);
    } catch (e) {
      print('sendNotification error: $e');
    }
  }

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
