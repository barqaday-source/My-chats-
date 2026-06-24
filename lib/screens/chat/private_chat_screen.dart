import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_snackbar.dart';
import '../profile/user_profile_screen.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  List<UserModel> _users = [];
  bool _loading = true; // يبدي يحمل مباشرة

  @override
  void initState() {
    super.initState();
    _loadRecentUsers(); // أول ما تفتح يجيب أحدث المسجلين
  }

  // يجيب أحدث 50 يوزر مسجل
  Future<void> _loadRecentUsers() async {
    setState(() => _loading = true);
    try {
      final meId = supabase.auth.currentUser?.id;
      final res = await supabase
       .from('profiles')
       .select('id, username, avatar_url, is_online, created_at, status_text')
       .neq('id', meId?? '') // لا تطلع نفسك
       .order('created_at', ascending: false) // الأحدث أول
       .limit(50);

      if (mounted) {
        setState(() {
          _users = res.map((e) => UserModel.fromJson(e)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Load users error: $e');
      if (mounted) {
        setState(() => _loading = false);
        showAppSnack(context, 'فشل تحميل المستخدمين', success: false);
      }
    }
  }

  // البحث
  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _loadRecentUsers(); // إذا مسح البحث، رجع الأحدث
      return;
    }

    setState(() => _loading = true);

    try {
      final meId = supabase.auth.currentUser?.id;
      final res = await supabase
       .from('profiles')
       .select('id, username, avatar_url, is_online, created_at, status_text')
       .ilike('username', '%$query%') // بحث جزئي
       .neq('id', meId?? '')
       .limit(50);

      if (mounted) {
        setState(() {
          _users = res.map((e) => UserModel.fromJson(e)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openProfile(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: user.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title: const Text(
          'المستخدمون',
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // حقل البحث - BorderRadius 16 فخم
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              style: const TextStyle(fontFamily: 'Tajawal'),
              decoration: InputDecoration(
                hintText: 'ابحث عن مستخدم...',
                hintStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSub),
                suffixIcon: _searchController.text.isNotEmpty
                 ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: AppColors.textSub),
                      onPressed: () {
                        _searchController.clear();
                        _loadRecentUsers();
                      },
                    )
                  : null,
                filled: true,
                fillColor: AppColors.bgCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), // Premium: 16
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // الليست
          Expanded(
            child: _loading
             ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _users.isEmpty
               ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_rounded, 
                          size: 64, 
                          color: AppColors.textSub.withOpacity(0.5)
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'لا يوجد مستخدمين',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            color: AppColors.textSub,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return InkWell(
                        onTap: () => _openProfile(user),
                        borderRadius: BorderRadius.circular(16), // Premium: 16
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(16), // Premium: 16
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                url: user.avatarUrl,
                                name: user.username,
                                isOnline: user.isOnline,
                                size: 48,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.username,
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    if (user.statusText!= null && user.statusText!.isNotEmpty)...[
                                      const SizedBox(height: 4),
                                      Text(
                                        user.statusText!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 13,
                                          color: AppColors.textSub,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_left_rounded,
                                color: AppColors.textSub,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
