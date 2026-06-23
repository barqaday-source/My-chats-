import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/supabase_config.dart';
import '../widgets/user_avatar.dart';
import '../widgets/status_chip.dart';
import 'profile/user_profile_screen.dart';

class UsersGridScreen extends StatefulWidget {
  const UsersGridScreen({super.key});
  @override
  State<UsersGridScreen> createState() => _UsersGridScreenState();
}

class _UsersGridScreenState extends State<UsersGridScreen> {
  final _sb = Supabase.instance.client;
  String _query = '';
  List<Map<String, dynamic>> _users = []; // NEW
  List<Map<String, dynamic>> _filteredUsers = []; // NEW
  bool _isLoading = true; // NEW

  @override
  void initState() {
    super.initState();
    _loadAllUsers(); // NEW: نجيب الكل أول ما تفتح
  }

  // NEW: نحمل كل المستخدمين مرة وحدة
  Future<void> _loadAllUsers() async {
    setState(() => _isLoading = true);
    try {
      final myId = _sb.auth.currentUser?.id;
      var q = _sb.from(SupabaseConfig.tUsers)
         .select('id, username, avatar_url, bio, is_online, status_text');

      if (myId!= null) {
        q = q.neq('id', myId); // ما نعرض نفسك
      }

      final res = await q.order('is_online', ascending: false).limit(100);
      _users = List<Map<String, dynamic>>.from(res);
      _filterUsers(); // نفلتر حسب البحث الحالي
    } catch (e) {
      debugPrint('Error loading users: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // NEW: فلترة محلية بدون ما نرجع للسيرفر
  void _filterUsers() {
    if (_query.isEmpty) {
      _filteredUsers = _users;
    } else {
      _filteredUsers = _users.where((u) {
        final name = (u['username']?? '').toString().toLowerCase();
        return name.contains(_query.toLowerCase());
      }).toList();
    }
    setState(() {});
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
              onChanged: (v) {
                _query = v;
                _filterUsers(); // NEW: فلترة محلية سريعة
              },
              decoration: InputDecoration(
                hintText: 'ابحث عن مستخدم...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading // CHANGED: بدل FutureBuilder
               ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredUsers.isEmpty
                   ? const Center(
                        child: Text('لا يوجد مستخدمين',
                          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)
                        )
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.92,
                        ),
                        itemCount: _filteredUsers.length, // CHANGED
                        itemBuilder: (_, i) {
                          final u = _filteredUsers[i]; // CHANGED
                          final online = u['is_online'] == true;
                          final name = u['username']?? 'مستخدم';
                          final bio = (u['bio']?? '').toString();
                          final statusText = (u['status_text']?? '').toString();

                          return GestureDetector(
                            onTap: () => _openProfile(u),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.card,
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
                                    onTap: () => _openProfile(u), // NEW: حتى الضغط عالصورة يودي
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
                                  if (statusText.isNotEmpty)...[
                                    StatusChip(statusText),
                                  ] else...[
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
}
