import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/user_avatar.dart';
import '../chat/private_chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _userService = UserService();
  UserModel? _user;
  bool _loading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    try {
      final userData = await _userService.getUserById(widget.userId);
      final me = context.read<AuthProvider>().user!;
      final following = await _userService.isFollowing(me.id, widget.userId);
      if (mounted) {
        setState(() {
          _user = UserModel.fromJson(userData);
          _isFollowing = following;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل الملف: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_user == null) return;
    final me = context.read<AuthProvider>().user!;
    setState(() => _isFollowing =!_isFollowing);
    try {
      if (_isFollowing) {
        await _userService.followUser(me.id, _user!.id);
      } else {
        await _userService.unfollowUser(me.id, _user!.id);
      }
    } catch (e) {
      setState(() => _isFollowing =!_isFollowing);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _startChat() {
    if (_user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(otherUser: _user!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title: Text(
          _user?.username?? 'الملف الشخصي',
          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGrad),
        child: _loading
      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _user == null
         ? const Center(
                    child: Text(
                      'المستخدم غير موجود',
                      style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildStats(),
                      const SizedBox(height: 24),
                      _buildActions(),
                      const SizedBox(height: 24),
                      _buildInfo(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        UserAvatar(
          url: _user!.avatarUrl,
          name: _user!.username,
          isOnline: _user!.isOnline,
          size: 90,
        ),
        const SizedBox(height: 12),
        Text(
          _user!.username,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _user!.bio?? 'لا يوجد نبذة',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.textSub,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('المتابعون', _user!.followersCount.toString()),
        _buildStatItem('يتابع', _user!.followingCount.toString()),
        _buildStatItem('المنشورات', _user!.postsCount.toString()),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.textSub,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    final me = context.read<AuthProvider>().user!;
    if (me.id == _user!.id) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _toggleFollow,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isFollowing? AppColors.bgCard : AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.primary),
              ),
            ),
            icon: Icon(
              _isFollowing? Icons.person_remove_rounded : Icons.person_add_rounded,
              color: _isFollowing? AppColors.primary : Colors.white,
            ),
            label: Text(
              _isFollowing? 'إلغاء المتابعة' : 'متابعة',
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: _isFollowing? AppColors.primary : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _startChat,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.bgCard,
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.glassBorder),
            ),
          ),
          child: const Icon(Icons.message_rounded, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.email_rounded, 'البريد', _user!.email?? 'مخفي'),
          const Divider(color: AppColors.glassBorder),
          _buildInfoRow(Icons.calendar_today_rounded, 'تاريخ الانضمام',
            '${_user!.createdAt.day}/${_user!.createdAt.month}/${_user!.createdAt.year}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.textSub,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
