import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_config.dart';
import '../../models/user_model.dart';
import '../../models/notification_model.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_snackbar.dart';
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
  List<Map<String, dynamic>> _pendingRooms = [];
  bool _loading = true;
  bool _isAdmin = false;
  bool _busy = false;

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
      final role = userData['role'] as String??? 'user';
      if (role == 'admin') {
        _isAdmin = true;
        await _loadStatic();
      } else {
        if (mounted) {
          showAppSnack(context, 'ليس لديك صلاحية', success: false);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Check admin error: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _loadStatic() async {
    setState(() => _loading = true);
    try {
      final roomsData = await _sb.from(SupabaseConfig.tRooms)
        .select()
        .eq('is_approved', false)
        .order('created_at', ascending: false);
      _pendingRooms = List<Map<String, dynamic>>.from(roomsData);

      final contactData = await _sb.from('app_contact').select().eq('id', 1).maybeSingle();
      if (contactData!= null) {
        adminPhone = contactData['whatsapp_number']?? '';
        adminEmail = contactData['contact_email']?? '';
        adminMessage = contactData['support_message']?? '';
      }
    } catch (e) {
      debugPrint('Load admin data error: $e');
      if (mounted) showAppSnack(context, 'فشل تحميل بيانات الإدارة', success: false);
    }
    if (mounted) setState(() => _loading = false);
  }

  Stream<List<UserModel>> _usersStream() {
    return _sb.from(SupabaseConfig.tUsers)
     .stream(primaryKey: ['id'])
     .order('created_at', ascending: false)
     .map((list) => list.map((j) => UserModel.fromMap(j)).toList());
  }

  Stream<List<Map<String, dynamic>>> _reportsStream() {
    return _sb.from(SupabaseConfig.tReports)
     .stream(primaryKey: ['id'])
     .order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>?> _getUserMini(String userId) async {
    return await _sb.from(SupabaseConfig.tUsers)
     .select('id, username, avatar_url')
     .eq('id', userId)
     .maybeSingle();
  }

  Future<void> _blockUser(String uid, String username) async {
    if (_busy) return;
    _busy = true;
    try {
      final res = await _sb.from(SupabaseConfig.tUsers)
        .update({
            'is_blocked': true,
            'blocked_at': DateTime.now().toIso8601String(),
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
      if (mounted) showAppSnack(context, 'تم حظر $username نهائيا', success: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل الحظر: $e', success: false);
    } finally {
      _busy = false;
    }
  }

  Future<void> _unblockUser(String uid, String username) async {
    if (_busy) return;
    _busy = true;
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
      if (mounted) showAppSnack(context, 'تم إلغاء حظر $username', success: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل إلغاء الحظر: $e', success: false);
    } finally {
      _busy = false;
    }
  }

  Future<void> _replyReport(String reportId, String userId, String reply) async {
    try {
      await _sb.from(SupabaseConfig.tReports)
        .update({'reply': reply, 'status': 'replied', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', reportId);
      await _notifSvc.sendNotification(NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId, title: 'رد على بلاغك', body: reply,
        type: 'report_reply', createdAt: DateTime.now(),
      ));
      if (mounted) showAppSnack(context, 'تم الرد', success: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل الرد: $e', success: false);
    }
  }

  Future<void> _approveRoom(String roomId, String ownerId) async {
    try {
      await _sb.from(SupabaseConfig.tRooms)
        .update({'is_approved': true})
        .eq('id', roomId);
      if (mounted) showAppSnack(context, 'تمت الموافقة على الغرفة', success: true);
      await _loadStatic();
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل الموافقة: $e', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin &&!_loading) {
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
                      // المستخدمون - لحظي
                      StreamBuilder<List<UserModel>>(
                        stream: _usersStream(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                          }
                          return _UsersTab(
                            users: snap.data!,
                            myId: Supabase.instance.client.auth.currentUser?.id?? '',
                            onBlock: _blockUser,
                            onUnblock: _unblockUser);
                        },
                      ),
                      // البلاغات - لحظي
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _reportsStream(),
                        builder: (context, snap) {
                          final reports = snap.data?? [];
                          return _ReportsTab(
                            reports: reports,
                            onReply: _replyReport,
                            getUserMini: _getUserMini,
                          );
                        },
                      ),
                      _PendingRoomsTab(rooms: _pendingRooms, onApprove: _approveRoom),
                      _ContactTab(phone: adminPhone, email: adminEmail, message: adminMessage, onEdit: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditContactScreen()));
                        _loadStatic();
                      }),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  final List<UserModel> users;
  final String myId;
  final Function(String, String) onBlock;
  final Function(String, String) onUnblock;

  const _UsersTab({
    required this.users,
    required this.myId,
    required this.onBlock,
    required this.onUnblock,
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
            color: isBlocked? AppColors.danger.withOpacity(0.1) : AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isBlocked? AppColors.danger.withOpacity(0.5) : AppColors.glassBorder, width: 0.8),
          ),
          child: Row(children: [
            UserAvatar(url: u.avatarUrl, name: u.username, size: 42, isOnline: u.isOnline),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.username, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(u.email?? '', style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 11), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isAdmin? AppColors.primary : AppColors.bgCard2).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAdmin? 'مدير' : 'عضو',
                      style: TextStyle(fontFamily: 'Tajawal', color: isAdmin? AppColors.primary : AppColors.textSub, fontSize: 10),
                    ),
                  ),
                  if (isBlocked)...[
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
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: isBlocked? 'unblock' : 'block',
                    child: Text(
                      isBlocked? 'إلغاء الحظر' : 'حظر نهائي',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: isBlocked? AppColors.success : AppColors.danger,
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

class ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final Future<Map<String, dynamic>?> Function(String) getUserMini;
  final Function(String, String, String) onReply;
  const ReportCard({super.key, required this.report, required this.onReply, required this.getUserMini});

  @override
  Widget build(BuildContext context) {
    final reporterId = report['reporter_id'] as String?;
    final reportedId = report['reported_id'] as String?;
    final reason = report['reason']?? 'بدون سبب';
    final status = report['status']?? 'new';
    final createdAt = report['created_at']?.toString()?? '';

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        reporterId!= null? getUserMini(reporterId) : Future.value(null),
        reportedId!= null? getUserMini(reportedId) : Future.value(null),
      ]),
      builder: (context, snap) {
        final reporter = snap.data?[0]?? {};
        final reported = snap.data?[1]?? {};
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              UserAvatar(url: reported['avatar_url'], name: reported['username']?? 'مستخدم', size: 38),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(reported['username']?? 'مستخدم',
                    style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontWeight: FontWeight.w700)),
                Text('بلاغ من: ${reporter['username']?? 'مجهول'}',
                    style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(status,
                    style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.warning, fontSize: 11)),
              ),
            ]),
            const SizedBox(height: 10),
            Text(reason,
                style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 13)),
            if (createdAt.isNotEmpty)...[
              const SizedBox(height: 4),
              Text(createdAt.length > 16? createdAt.substring(0, 16) : createdAt,
                  style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 11)),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.glassBorder)),
                  onPressed: () => onReply(report['id'], reportedId?? '', 'تم رفض البلاغ'),
                  child: const Text('تجاهل', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: () => onReply(report['id'], reportedId?? '', 'تم حظر المستخدم'),
                  child: const Text('حظر المستخدم', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
                ),
              ),
            ])
          ]),
        );
      },
    );
  }
}

class _ReportsTab extends StatelessWidget {
  final List<Map<String, dynamic>> reports;
  final Function(String, String, String) onReply;
  final Future<Map<String, dynamic>?> Function(String) getUserMini;
  const _ReportsTab({required this.reports, required this.onReply, required this.getUserMini});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const Center(child: Text('لا توجد بلاغات', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: reports.length,
      itemBuilder: (_, i) => ReportCard(report: reports[i], onReply: onReply, getUserMini: getUserMini),
    );
  }
}

class _PendingRoomsTab extends StatelessWidget {
  final List<Map<String, dynamic>> rooms;
  final Function(String, String) onApprove;
  const _PendingRoomsTab({required this.rooms, required this.onApprove});

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const Center(child: Text('لا توجد غرف معلقة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rooms.length,
      itemBuilder: (_, i) {
        final r = rooms[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.glassBorder)),
          child: Row(children: [
            Expanded(child: Text(r['name']?? 'غرفة', style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () => onApprove(r['id'], r['owner_id']?? ''),
              child: const Text('موافقة', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
            )
          ]),
        );
      },
    );
  }
}

class _ContactTab extends StatelessWidget {
  final String phone, email, message;
  final VoidCallback onEdit;
  const _ContactTab({required this.phone, required this.email, required this.message, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.phone, color: AppColors.primary),
          title: Text(phone.isEmpty? 'لا يوجد' : phone, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
          subtitle: const Text('واتساب', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
        ),
        ListTile(
          leading: const Icon(Icons.email_rounded, color: AppColors.primary),
          title: Text(email.isEmpty? 'لا يوجد' : email, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
          subtitle: const Text('البريد', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded),
          label: const Text('تعديل معلومات التواصل', style: TextStyle(fontFamily: 'Tajawal')),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        )
      ],
    );
  }
}
