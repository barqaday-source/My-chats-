import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/user_avatar.dart';
import '../../services/follow_service.dart';
import '../profile/user_profile_screen.dart';

class FollowsTab extends StatefulWidget {
  const FollowsTab({super.key});
  @override State<FollowsTab> createState() => _FollowsTabState();
}

class _FollowsTabState extends State<FollowsTab> {
  final supabase = Supabase.instance.client;
  final _follow = FollowService();
  int _seg = 0; // 0 المتابعون / 1 أتابعهم

  Future<List<Map<String, dynamic>>> _load() async {
    final me = supabase.auth.currentUser!.id;
    final isFollowers = _seg == 0;
    final col = isFollowers? 'following_id' : 'follower_id';
    final joinCol = isFollowers? 'follower_id' : 'following_id';

    final res = await supabase
       .from('follows')
       .select('follower_id, following_id, profiles!follows_${joinCol}_fkey(*)')
       .eq(col, me)
       .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        // segmented نعناعي مفرغ
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                _segBtn('المتابعون', 0),
                _segBtn('أتابعهم', 1),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder(
            key: ValueKey(_seg),
            future: _load(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return const Center(child: Text('لا يوجد أحد هنا بعد', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final row = items[i];
                  final u = row['profiles'] as Map<String, dynamic>;
                  final userId = u['id'] as String;

                  // دخول تدريجي ناعم
                  return TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 250 + i * 40),
                    curve: Curves.easeOutCubic,
                    builder: (context, double v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - v)),
                        child: child,
                      ),
                    ),
                    child: _userRow(u, userId),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _segBtn(String label, int idx) {
    final active = _seg == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _seg = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active? AppColors.primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: active? AppColors.primary : AppColors.textSub,
            ),
          ),
        ),
      ),
    );
  }

  Widget _userRow(Map<String, dynamic> u, String userId) {
    final isOnline = u['is_online'] == true;
    final name = u['username']?? 'مستخدم';
    final status = u['status'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId))),
                child: UserAvatar(url: u['avatar_url'], name: name, size: 52, isOnline: false),
              ),
              if (isOnline)
                Positioned(
                  right: 2, bottom: 2,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.online,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 2),
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
                Text(name, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, color: AppColors.text, fontSize: 14)),
                if (status!= null && status.isNotEmpty)
                  Text(status, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub)),
              ],
            ),
          ),
          // أيقونات مفرغة نعناعية فقط
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            color: AppColors.primary,
            iconSize: 22,
            onPressed: () {},
            tooltip: 'مراسلة',
          ),
          IconButton(
            icon: Icon(
              _seg == 0? Icons.person_add_alt_1_outlined : Icons.person_remove_outlined,
            ),
            color: AppColors.primary,
            iconSize: 22,
            onPressed: () async {
              await _follow.toggleFollow(userId);
              setState(() {});
            },
            tooltip: _seg == 0? 'رد المتابعة' : 'إلغاء',
          ),
        ],
      ),
    );
  }
}
