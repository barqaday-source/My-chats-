import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/user_avatar.dart';

class ActivityTab extends StatefulWidget {
  const ActivityTab({super.key});
  @override State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _load() async {
    final me = supabase.auth.currentUser!.id;
    final res = await supabase
      .from('notifications')
      .select('*, actor:actor_id(id, username, avatar_url)')
      .eq('user_id', me)
      .order('created_at', ascending: false)
      .limit(50);
    return List<Map<String, dynamic>>.from(res);
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'follow': return Icons.person_add_alt_outlined;
      case 'visit': return Icons.visibility_outlined;
      case 'message': return Icons.chat_bubble_outline_rounded;
      case 'room': return Icons.mic_none_rounded;
      default: return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return const Center(child: Text('لا توجد إشعارات بعد', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final n = items[i];
            final actor = n['actor'] as Map<String, dynamic>?;
            final isRead = n['is_read'] == true;
            final type = n['type'] as String;

            return TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 280 + i * 35),
              curve: Curves.easeOutCubic,
              builder: (context, double v, child) => Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(30 * (1 - v), 0),
                  child: child,
                ),
              ),
              child: Dismissible(
                key: ValueKey(n['id']),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: const Icon(Icons.check_rounded, color: AppColors.primary),
                ),
                onDismissed: (_) async {
                  await supabase.from('notifications').update({'is_read': true}).eq('id', n['id']);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRead? AppColors.glassBg.withOpacity(0.5) : AppColors.glassBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isRead? AppColors.glassBorder : AppColors.primary.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      // صورة الشخص + بادج نوع الإشعار
                      Stack(
                        children: [
                          actor!= null
                           ? UserAvatar(
                                url: actor['avatar_url'],
                                name: actor['username']?? '؟',
                                size: 48,
                              )
                            : Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withOpacity(0.10),
                                ),
                                child: Icon(_iconFor(type), color: AppColors.primary, size: 20),
                              ),
                          // بادج نوع الإشعار
                          Positioned(
                            right: -2, bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: Icon(_iconFor(type), size: 12, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              actor!= null? '${actor['username']?? ''} • ${n['title']}' : n['title'],
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: isRead? FontWeight.w500 : FontWeight.w700,
                                color: AppColors.text,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (n['body']!= null)
                              Text(n['body'], style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub)),
                          ],
                        ),
                      ),
                      // نقطة غير مقروء
                      if (!isRead)
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0.6, end: 1.0),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeInOut,
                          builder: (context, double v, _) => Opacity(
                            opacity: v,
                            child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                          ),
                          onEnd: () { if(mounted) setState(() {}); },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
