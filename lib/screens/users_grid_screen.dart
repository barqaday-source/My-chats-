import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/supabase_config.dart';
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
     .select('id, username, avatar_url, bio, is_online')
     .eq('is_blocked', false);

    if (myId != null) {
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        elevation: 0.5,
        title: const Text('المستخدمون', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
              decoration: InputDecoration(
                hintText: 'ابحث عن مستخدم...',
                hintStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSub),
                filled: true,
                fillColor: AppColors.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: users.length,
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final online = u['is_online'] == true;
                    return GestureDetector(
                      onTap: () => _openProfile(u),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 42,
                                backgroundColor: AppColors.bgCard,
                                backgroundImage: u['avatar_url'] != null
                                 ? NetworkImage(u['avatar_url']) : null,
                                child: u['avatar_url'] == null
                                 ? Text((u['username'] ?? '؟')[0],
                                      style: const TextStyle(fontSize: 22, color: AppColors.primary))
                                  : null,
                              ),
                              if (online)
                                Positioned(
                                  bottom: 2, right: 2,
                                  child: Container(width: 12, height: 12,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.bg, width: 2)
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            u['username'] ?? 'مستخدم',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppColors.white),
                            textAlign: TextAlign.center,
                          ),
                        ],
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
