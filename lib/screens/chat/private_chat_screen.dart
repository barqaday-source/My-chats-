import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/user_avatar.dart';

class ProfileVisitorsScreen extends StatefulWidget {
  const ProfileVisitorsScreen({super.key});

  @override
  State<ProfileVisitorsScreen> createState() => _ProfileVisitorsScreenState();
}

class _ProfileVisitorsScreenState extends State<ProfileVisitorsScreen> {
  final _profileService = ProfileService();
  List<Map<String, dynamic>> _visitors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVisitors();
  }

  Future<void> _loadVisitors() async {
    setState(() => _loading = true);
    try {
      final user = context.read<AuthProvider>().user!;
      final visitors = await _profileService.getProfileVisitors(user.id);
      if (!mounted) return;
      setState(() {
        _visitors = visitors;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAppSnack(context, 'فشل تحميل الزوار', success: false);
      }
    }
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 80,
        title: const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'زوار ملفي',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGrad),
        child: _loading
         ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _visitors.isEmpty
             ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadVisitors,
                    color: AppColors.primary,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _visitors.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final visitor = _visitors[index];
                        return _buildVisitorTile(visitor);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.visibility_rounded, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا يوجد زوار بعد',
            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'سيظهر هنا من زار ملفك الشخصي',
            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorTile(Map<String, dynamic> visitor) {
    final userId = visitor['visitor_id'] as String;
    final username = visitor['username'] as String??? 'مستخدم'; // صلحت??? إلى??
    final avatarUrl = visitor['avatar_url'] as String?;
    final visitedAt = DateTime.parse(visitor['visited_at'] as String);

    return InkWell(
      onTap: () => _openProfile(userId),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            // السهم
            const Icon(Icons.chevron_left_rounded, color: AppColors.textSub, size: 20),
            const SizedBox(width: 8),
            // المحتوى
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'زار ملفك ${_formatTime(visitedAt)}',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      color: AppColors.textSub,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // الصورة
            UserAvatar(
              url: avatarUrl,
              name: username,
              isOnline: false,
              size: 48,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) {
      return 'قبل ${diff.inDays} يوم';
    } else if (diff.inHours > 0) {
      return 'قبل ${diff.inHours} س';
    } else if (diff.inMinutes > 0) {
      return 'قبل ${diff.inMinutes} د';
    } else {
      return 'الآن';
    }
  }
}
