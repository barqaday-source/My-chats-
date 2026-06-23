import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/user_avatar.dart';
import '../profile/user_profile_screen.dart';

class ProfileVisitsScreen extends StatefulWidget {
  const ProfileVisitsScreen({super.key});

  @override
  State<ProfileVisitsScreen> createState() => _ProfileVisitsScreenState();
}

class _ProfileVisitsScreenState extends State<ProfileVisitsScreen> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _visits = [];

  @override
  void initState() {
    super.initState();
    _loadVisitors();
  }

  Future<void> _loadVisitors() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final res = await supabase
          .from('profile_visits')
          .select('visited_at, visitor:profiles!visitor_id(id, username, avatar_url, is_online)')
          .eq('profile_id', myId)
          .order('visited_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _visits = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading visitors: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} س';
    if (diff.inDays < 7) return 'قبل ${diff.inDays} ي';
    if (diff.inDays < 30) return 'قبل ${(diff.inDays / 7).floor()} أسبوع';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _visits.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadVisitors,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _visits.length + 1, // +1 للعنوان
                    itemBuilder: (context, index) {
                      // أول عنصر هو العنوان
                      if (index == 0) {
                        return const Padding(
                          padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
                          child: Text(
                            'زوار ملفي',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                        );
                      }

                      final visit = _visits[index - 1];
                      final visitor = visit['visitor'];
                      if (visitor == null) return const SizedBox.shrink();
                      
                      final visitedAt = DateTime.parse(visit['visited_at']).toLocal();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: UserAvatar(
                            url: visitor['avatar_url'],
                            name: visitor['username'] ?? 'U',
                            isOnline: visitor['is_online'] ?? false,
                            size: 48,
                          ),
                          title: Text(
                            visitor['username'] ?? 'مستخدم',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.text,
                            ),
                          ),
                          subtitle: Text(
                            'زار ملفك ${_timeAgo(visitedAt)}',
                            style: const TextStyle(
                              color: AppColors.textSub,
                              fontSize: 13,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_left_rounded,
                            color: AppColors.textSub,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfileScreen(userId: visitor['id']),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.visibility_off_rounded,
                size: 64,
                color: AppColors.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'لا يوجد زوار بعد',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'عندما يزور أحد ملفك الشخصي\nسيظهر هنا مع وقت الزيارة',
              style: TextStyle(
                color: AppColors.textSub,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
