import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_config.dart';
import '../../models/user_model.dart';
import '../../models/notification_model.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/user_avatar.dart';
import '../../providers/auth_provider.dart';
import 'edit_contact_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _sb = Supabase.instance.client;
  final _authSvc = AuthService();
  final _notifSvc = NotificationService();
  List<UserModel> _users = [];
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _pendingRooms = [];
  bool _loading = true;
  bool _isAdmin = false;

  String adminPhone = '';
  String adminEmail = '';
  String adminMessage = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _checkAdminAndLoad();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAndLoad() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    try {
      final userData = await _sb.from(SupabaseConfig.tUsers)
        .select('role')
        .eq('id', user.id)
        .single();
      final role = userData['role'] as String? ?? 'user';
      if (role == 'admin') {
        _isAdmin = true;
        await _load();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ليس لديك صلاحية', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Check admin error: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rawUsers = await _authSvc.getAllUsers();
      _users = rawUsers.map((json) => UserModel.fromMap(json)).toList();

      final rep = await _sb.from(SupabaseConfig.tReports)
        .select('*, reporter:reporter_id(username, avatar_url), reported:reported_id(username, avatar_url)')
        .order('created_at', ascending: false);
      _reports = List<Map<String, dynamic>>.from(rep);

      final roomsData = await _sb.from(SupabaseConfig.tRooms)
        .select()
        .eq('is_approved', false)
        .order('created_at', ascending: false);
      _pendingRooms = List<Map<String, dynamic>>.from(roomsData);

      final contactData = await _sb.from('app_contact').select().eq('id', 1).maybeSingle();
      if (contactData != null) {
        adminPhone = contactData['whatsapp_number'] ?? '';
        adminEmail = contactData['contact_email'] ?? '';
        adminMessage = contactData['support_message'] ?? '';
      }
    } catch (e) {
      debugPrint('Load admin data error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  // --- ترقية لمدير / إزالة الإدارة ---
  Future<void> _changeRole(String userId, String role) async {
    try {
      final res = await _sb.from(SupabaseConfig.tUsers)
        .update({'role': role})
        .eq('id', userId)
        .select();
      
      if (res.isEmpty) throw Exception('فشل التحديث - تحقق من RLS');
      
      await _notifSvc.showNotification('تم التحديث', role == 'admin' ? 'تم ترقية المستخدم لمدير' : 'تم إزالة صلاحية المدير');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تغيير الصلاحية: $e', style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- حظر نهائي يمنع الدخول ---
  Future<void> _blockUser(String uid, String username) async {
    try {
      final res = await _sb.from(SupabaseConfig.tUsers)
        .update({
          'is_blocked': true,
          'blocked_at': DateTime.now().toIso8601String(),
          'role': 'user' // نشيل منه الإدارة إذا كان مدير
        })
        .eq('id', uid)
        .select();
      
      if (res.isEmpty) throw Exception('فشل الحظر - تحقق من RLS');

      await _notifSvc.sendNotification(NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: uid,
        title: 'تم حظر حسابك',
        body: 'تم حظر حسابك نهائيا من قبل الإدارة.',
        type: 'account_blocked',
        createdAt: DateTime.now(),
      ));
      await _notifSvc.showNotification('تم الحظر', 'تم حظر $username نهائيا');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحظر: $e', style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _unblockUser(String uid, String username) async {
    try {
      final res = await _sb.from(SupabaseConfig.tUsers)
        .update({'is_blocked': false, 'blocked_at': null})
        .eq('id', uid)
        .select();
      
      if (res.isEmpty) throw Exception('فشل إلغاء الحظر');
      
      await _notifSvc.sendNotification(NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: uid,
        title: 'تم إلغاء الحظر',
        body: 'تم إلغاء حظر حسابك. يمكنك الآن تسجيل الدخول.',
        type: 'account_unblocked',
        createdAt: DateTime.now(),
      ));
      await _notifSvc.showNotification('تم إلغاء الحظر', 'تم إلغاء حظر $username');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إلغاء الحظر: $e', style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
      }
    }
  }

  // باقي الدوال _replyReport / _approveRoom نفس ملفك القديم، فقط ضيف .select()
  Future<void> _replyReport(String reportId, String userId, String reply) async {
    try {
      await _sb.from(SupabaseConfig.tReports)
        .update({'reply': reply, 'status': 'replied', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', reportId)
        .select();
      await _notifSvc.sendNotification(NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId, title: 'رد على بلاغك', body: reply,
        type: 'report_reply', createdAt: DateTime.now(),
      ));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الرد: $e', style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _approveRoom(String roomId, String ownerId) async {
    try {
      await _sb.from(SupabaseConfig.tRooms)
        .update({'is_approved': true})
        .eq('id', roomId)
        .select();
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الموافقة: $e', style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin && !_loading) {
      return const Scaffold(body: Center(child: Text('ليس لديك صلاحية', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text))));
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGrad),
        child: SafeArea(
          child: Column(children: [
            AppBar(
              backgroundColor: Colors.transparent, elevation: 0,
              title: const Text('لوحة الإدارة', style: TextStyle(fontFamily: 'Tajawal')),
              bottom: TabBar(
                controller: _tabs,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.white,
                unselectedLabelColor: AppColors.textSub,
                labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 12),
                tabs: const [
                  Tab(text: 'المستخدمون'),
                  Tab(text: 'البلاغات'),
                  Tab(text: 'الغرف'),
                  Tab(text: 'تواصل معنا'),
                ],
              ),
            ),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(controller: _tabs, children: [
                    _UsersTab(
                      users: _users,
                      myId: Supabase.instance.client.auth.currentUser?.id ?? '',
                      onBlock: _blockUser,
                      onUnblock: _unblockUser,
                      onChangeRole: _changeRole),
                    _ReportsTab(reports: _reports, onReply: _replyReport),
                    _PendingRoomsTab(rooms: _pendingRooms, onApprove: _approveRoom),
                    _ContactTab(phone: adminPhone, email: adminEmail, message: adminMessage, onEdit: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditContactScreen()));
                      _load();
                    }),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// --- تبويب المستخدمين: خيارين فقط ---
class _UsersTab extends StatelessWidget {
  final List<UserModel> users;
  final String myId;
  final Function(String, String) onBlock;
  final Function(String, String) onUnblock;
  final Function(String, String) onChangeRole;

  const _UsersTab({
    required this.users,
    required this.myId,
    required this.onBlock,
    required this.onUnblock,
    required this.onChangeRole,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i];
        final isAdmin = u.role == 'admin';
        final isBlocked = u.isBlocked;
        final isMe = u.id == myId;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isBlocked ? AppColors.danger.withOpacity(0.1) : AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isBlocked ? AppColors.danger.withOpacity(0.5) : AppColors.glassBorder, width: 0.8),
          ),
          child: Row(children: [
            UserAvatar(url: u.avatarUrl, name: u.username, size: 42, isOnline: u.isOnline),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.username, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(u.email ?? '', style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 11), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isAdmin ? AppColors.primary : AppColors.bgCard2).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAdmin ? 'مدير' : 'عضو',
                      style: TextStyle(fontFamily: 'Tajawal', color: isAdmin ? AppColors.primary : AppColors.textSub, fontSize: 10),
                    ),
                  ),
                  if (isBlocked) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Text('محظور', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger, fontSize: 10)),
                    ),
                  ],
                ]),
              ]),
            ),
            if (!isMe)
              PopupMenuButton<String>(
                color: AppColors.bgCard2,
                onSelected: (v) {
                  if (v == 'block') onBlock(u.id, u.username);
                  else if (v == 'unblock') onUnblock(u.id, u.username);
                  else onChangeRole(u.id, v); // v = 'admin' أو 'user'
                },
                itemBuilder: (_) => [
                  // خيار 1: ترقية / إزالة
                  PopupMenuItem(
                    value: isAdmin ? 'user' : 'admin',
                    child: Text(
                      isAdmin ? 'إزالة الإدارة' : 'جعله مدير',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: isAdmin ? AppColors.textSub : AppColors.primary,
                      ),
                    ),
                  ),
                  // خيار 2: حظر / فك حظر
                  PopupMenuItem(
                    value: isBlocked ? 'unblock' : 'block',
                    child: Text(
                      isBlocked ? 'إلغاء الحظر' : 'حظر نهائي',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: isBlocked ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ),
                ],
                child: const Icon(Icons.more_vert_rounded, color: AppColors.textSub),
              ),
          ]),
        );
      },
    );
  }
}

// _ReportsTab / _PendingRoomsTab / _ContactTab / _ContactCard
// اتركها مثل ما هي عندك، ما تغيرت
