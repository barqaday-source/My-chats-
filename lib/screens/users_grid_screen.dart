import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_config.dart';

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
    // بدّل ProfileScreen باسم شاشة البروفايل الحقيقية عندك
    // Navigator.push(context, MaterialPageRoute(
    // builder: (_) => ProfileScreen(userId: user['id'])
    // ));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundImage: user['avatar_url']!= null
                   ? NetworkImage(user['avatar_url']) : null,
                  child: user['avatar_url'] == null? const Icon(Icons.person, size: 40) : null,
                ),
                if (user['is_online'] == true)
                  Positioned(
                    bottom: 2, right: 2,
                    child: Container(width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C49A),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(user['username']?? 'مستخدم',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (user['bio']!= null && user['bio'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(user['bio'], textAlign: TextAlign.center),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('مراسلة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C49A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: PrivateChatScreen(userId: user['id'])
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('المستخدمون', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث عن مستخدم...',
                hintTextDirection: TextDirection.rtl,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
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
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF00C49A)));
                }
                final users = snap.data!;
                if (users.isEmpty) return const Center(child: Text('لا يوجد مستخدمين'));
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
                                backgroundColor: const Color(0xFFE0F5F0),
                                backgroundImage: u['avatar_url']!= null
                                 ? NetworkImage(u['avatar_url']) : null,
                                child: u['avatar_url'] == null
                                 ? Text((u['username']?? '؟')[0],
                                      style: const TextStyle(fontSize: 22, color: Color(0xFF00C49A)))
                                  : null,
                              ),
                              if (online)
                                Positioned(
                                  bottom: 2, right: 2,
                                  child: Container(width: 12, height: 12,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00C49A),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2)
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            u['username']?? 'مستخدم',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
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
