import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../services/notification_service.dart';
import '../../models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _svc = NotificationService();
  String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _deleteNotification(String id) async {
    try {
      await _svc.deleteNotification(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الإشعار', style: TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحذف', style: TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Text('سجل دخول أولاً', style: TextStyle(fontFamily: 'Tajawal'))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('الإشعارات', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'تعليم الكل كمقروء',
            onPressed: () => _svc.markAllRead(uid),
            icon: const Icon(Icons.done_all_rounded, color: AppColors.textSub),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _svc.userNotifications(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('لا توجد إشعارات', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = items[i];
              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                // هنا يصير الحذف
                onDismissed: (_) => _deleteNotification(n.id),
                child: InkWell(
                  onTap: () => _svc.markRead(n.id),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.isRead? AppColors.bgCard : AppColors.bgCard2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: n.isRead? Colors.transparent : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.title, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, color: AppColors.white)),
                              const SizedBox(height: 4),
                              Text(n.body, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
