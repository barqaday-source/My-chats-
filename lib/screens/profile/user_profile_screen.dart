import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/supabase_config.dart';
import '../widgets/user_avatar.dart';
import 'profile/user_profile_screen.dart';

class UsersGridScreen extends StatefulWidget {
  const UsersGridScreen({super.key});
  @override
  State<UsersGridScreen> createState() => _UsersGridScreenState();
}

class _UsersGridScreenState extends State<UsersGridScreen> {
  final _sb = Supabase.instance.client;
  String _query = '';

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final myId = _sb.auth.currentUser?.id;
    var q = _sb.from(SupabaseConfig.tUsers)
    .select('id, username, avatar_url, bio, is_online');

    if (myId!= null) {
      q = q.neq('id', myId);
    }
    if (_query.isNotEmpty) {
      q = q.ilike('username', '%$_query%');
    }
    final res = await q.order('is_online', ascending: false).limit(60);
    return List<Map<String, dynamic>>.from(res);
  }

  void _openProfile(Map<String, dynamic> user) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => UserProfileScreen(userId: user['id'])
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('المستخدمون', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              textDirection: TextDirection.rtl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'ابحث عن مستخدم...',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadUsers(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                final users = snap.data!;
                if (users.isEmpty) {
                  return const Center(child: Text('لا يوجد مستخدمين', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)));
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: users.length,
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final online = u['is_online'] == true;
                    final name = u['username']?? 'مستخدم';
                    final bio = (u['bio']?? '').toString();

                    return GestureDetector(
                      onTap: () => _openProfile(u),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.glassBorder, width: 0.8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            UserAvatar(
                              url: u['avatar_url'],
                              name: name,
                              size: 68,
                              isOnline: online,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              online? 'متصل الآن' : (bio.isNotEmpty? bio : 'غير متصل'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                color: online? AppColors.success : AppColors.textSub,
                                fontWeight: online? FontWeight.w600 : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
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
    );
  }
}
