import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_colors.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onRead;
  const NotificationsScreen({super.key, this.onRead});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final _svc = NotificationService();
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();
    _markRead();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;
    await _svc.markAllRead(uid);
    widget.onRead?.call();
  }

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

  IconData _icon(String type) {
    switch (type) {
      case 'message': return Icons.chat_bubble_rounded;
      case 'report_reply': return Icons.gavel_rounded;
      case 'admin': return Icons.admin_panel_settings_rounded;
      case 'account_blocked': return Icons.block_rounded;
      case 'account_unblocked': return Icons.check_circle_rounded;
      case 'room_approved': return Icons.meeting_room_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'message': return AppColors.primary;
      case 'report_reply': return AppColors.warning;
      case 'admin': return AppColors.danger;
      case 'account_blocked': return AppColors.danger;
      case 'account_unblocked': return AppColors.success;
      case 'room_approved': return AppColors.accent;
      default: return AppColors.accent;
    }
  }

  String _label(String type) {
    switch (type) {
      case 'message': return 'رسالة';
      case 'report_reply': return 'بلاغ';
      case 'admin': return 'إدارة';
      case 'account_blocked': return 'حظر';
      case 'account_unblocked': return 'رفع حظر';
      case 'room_approved': return 'غرفة';
      default: return 'إشعار';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.id?? '';
    return Container(
      decoration: BoxDecoration(gradient: AppColors.bgGrad),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('الإشعارات', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                  TextButton.icon(
                    onPressed: _markRead,
                    icon: const Icon(Icons.done_all_rounded, color: AppColors.primaryLight, size: 16),
                    label: const Text('قراءة الكل', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.primaryLight, fontSize: 13)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<NotificationModel>>(
                stream: _svc.userNotifications(uid),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  final notifs = snap.data!;
                  if (notifs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
                            child: const Icon(Icons.notifications_none_rounded, color: AppColors.textSub, size: 40),
                          ),
                          const SizedBox(height: 16),
                          const Text('لا توجد إشعارات', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          const Text('ستظهر إشعاراتك هنا', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 13)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                    itemCount: notifs.length,
                    itemBuilder: (_, i) {
                      final n = notifs[i];
                      final c = _color(n.type);
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 200 + i * 40),
                        builder: (_, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: child),
                        ),
                        child: Dismissible(
                          key: ValueKey(n.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerLeft,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          onDismissed: (_) => _deleteNotification(n.id),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: n.isRead? AppColors.bgCard : AppColors.bgCard2,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: n.isRead? AppColors.glassBorder : c.withOpacity(0.35), width: n.isRead? 0.5 : 1),
                              boxShadow: n.isRead? null : [BoxShadow(color: c.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: InkWell(
                              onTap: () => _svc.markRead(n.id),
                              borderRadius: BorderRadius.circular(18),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      children: [
                                        Container(
                                          width: 46, height: 46,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [c.withOpacity(0.25), c.withOpacity(0.08)],
                                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: c.withOpacity(0.3), width: 0.8),
                                          ),
                                          child: Icon(_icon(n.type), color: c, size: 22),
                                        ),
                                        if (!n.isRead)
                                          Positioned(
                                            top: 0, right: 0,
                                            child: Container(
                                              width: 10, height: 10,
                                              decoration: BoxDecoration(
                                                color: c, shape: BoxShape.circle,
                                                border: Border.all(color: AppColors.bgCard2, width: 1.5),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                                child: Text(_label(n.type), style: TextStyle(fontFamily: 'Tajawal', color: c, fontSize: 10, fontWeight: FontWeight.w700)),
                                              ),
                                              const Spacer(),
                                              Text(timeago.format(n.createdAt, locale: 'ar'), style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 10)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(n.title, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w700, height: 1.3)),
                                          const SizedBox(height: 4),
                                          Text(n.body, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 12, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
