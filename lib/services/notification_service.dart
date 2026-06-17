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

  // جلب عدد الإشعارات غير المقروءة من Supabase
  Future<int> unreadCount(String uid) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .eq('is_read', false);
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  // تعليم كل الإشعارات كمقروءة
  Future<void> markAllRead(String uid) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
    } catch (e) {
      print('markAllRead error: $e');
    }
  }

  // ستريم الإشعارات للمستخدم
  Stream<List<NotificationModel>> userNotifications(String uid) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((maps) => maps.map((map) => NotificationModel.fromJson(map)).toList());
  }

  // ارسال إشعار جديد لقاعدة البيانات + عرض محلي
  Future<void> sendNotification(NotificationModel notification) async {
    try {
      // 1. احفظ بقاعدة البيانات
      await _supabase.from('notifications').insert(notification.toJson());
      
      // 2. اعرض إشعار محلي
      await showNotification(notification.title, notification.body);
    } catch (e) {
      print('sendNotification error: $e');
    }
  }

  // عرض إشعار محلي
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
