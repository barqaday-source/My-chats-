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
  @override State<AdminPanelScreen> createState() => _AdminPanelScreenState();
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
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _checkAdminAndLoad() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) { if (mounted) Navigator.pop(context); return; }
    try {
      final userData = await _sb.from(SupabaseConfig.tUsers).select('role').eq('id', user.id).single();
      final role = userData['role'] as String?? 'user';
      if (role == 'admin') { _isAdmin = true; await _loadStatic(); }
      else { if (mounted) { showAppSnack(context, 'ليس لديك صلاحية', success: false); Navigator.pop(context); }}
    } catch (e) { debugPrint('Check admin error: $e'); if (mounted) Navigator.pop(context); }
  }

  Future<void> _loadStatic() async {
    setState(() => _loading = true);
    try {
      final roomsData = await _sb.from(SupabaseConfig.tRooms).select().eq('is_approved', false).order('created_at', ascending: false);
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
    return _sb.from(SupabaseConfig.tUsers).stream(primaryKey: ['id']).order('created_at', ascending: false)
     .map((list) => list.map((j) => UserModel.fromMap(j)).toList());
  }

  Stream<List<Map<String, dynamic>>> _reportsStream() {
    return _sb.from(SupabaseConfig.tReports).stream(primaryKey: ['id']).order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>?> _getUserMini(String userId) async {
    return await _sb.from(SupabaseConfig.tUsers).select('id, username, avatar_url').eq('id', userId).maybeSingle();
  }

  Future<void> _blockUser(String uid, String username) async {
    if (_busy) return; _busy = true;
    try {
      final res = await _sb.from(SupabaseConfig.tUsers).update({'is_banned': true, 'is_blocked': true}).eq('id', uid).select();
      if (res.isEmpty) throw Exception('فشل الحظر - تحقق من RLS');
      await _notifSvc.sendNotification(NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(), userId: uid,
        title: 'تم حظر حسابك', body: 'تم حظر حسابك نهائيا من قبل الإدارة.',
        type: 'account_blocked', createdAt: DateTime.now(),
      ));
      if (mounted) showAppSnack(context, 'تم حظر $username نهائيا', success: true);
    } catch (e) { if (mounted) showAppSnack(context, 'فشل الحظر: $e', success: false); }
    finally { _busy = false; }
  }

  Future<void> _unblockUser(String uid, String username) async {
    if (_busy) return; _busy = true;
    try {
      final res = await _sb.from(SupabaseConfig.tUsers).update({'is_banned': false, 'is_blocked': false}).eq('id', uid).select();
      if (res.isEmpty) throw Exception('فشل إلغاء الحظر');
      await _notifSvc.sendNotification(NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(), userId: uid,
        title: 'تم إلغاء الحظر', body: 'تم إلغاء حظر حسابك. يمكنك الآن تسجيل الدخول.',
        type: 'account_unblocked', createdAt: DateTime.now(),
      ));
      if (mounted) showAppSnack(context, 'تم إلغاء حظر $username', success: true);
    } catch (e) { if (mounted) showAppSnack(context, 'فشل إلغاء الحظر: $e', success: false); }
    finally { _busy = false; }
  }

  Future<void> _replyReport(String reportId, String userId, String reply, {bool banUser = false}) async {
    try {
      await _sb.from(SupabaseConfig.tReports).update({'reply': reply, 'status': 'replied', 'updated_at': DateTime.now().toIso8601String()}).eq('id', reportId);
      if (banUser && userId.isNotEmpty) {
        await _sb.from(SupabaseConfig.tUsers).update({'is_banned': true, 'is_blocked': true}).eq('id', userId);
      }
      await _notifSvc.sendNotification(NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(), userId: userId, title: 'رد على بلاغك', body: reply,
        type: 'report_reply', createdAt: DateTime.now(),
      ));
      if (mounted) showAppSnack(context, banUser? 'تم حظر المستخدم والرد' : 'تم الرد', success: true);
    } catch (e) { if (mounted) showAppSnack(context, 'فشل الرد: $e', success: false); }
  }

  Future<void> _approveRoom(String roomId, String ownerId) async {
    try {
      await _sb.from(SupabaseConfig.tRooms).update({'is_approved': true}).eq('id', roomId);
      if (mounted) showAppSnack(context, 'تمت الموافقة على الغرفة', success: true);
      await _loadStatic();
    } catch (e) { if (mounted) showAppSnack(context, 'فشل الموافقة: $e', success: false); }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_isAdmin &&!_loading) {
      return const Scaffold(body: Center(child: Text('ليس لديك صلاحية')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الإدارة'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.group_rounded), text: 'المستخدمين'),
            Tab(icon: Icon(Icons.flag_rounded), text: 'البلاغات'),
            Tab(icon: Icon(Icons.meeting_room_rounded), text: 'الغرف'),
            Tab(icon: Icon(Icons.support_agent_rounded), text: 'التواصل'),
          ],
        ),
      ),
      body: _loading
       ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            StreamBuilder<List<UserModel>>(
              stream: _usersStream(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                return _UsersTab(users: snap.data!, myId: Supabase.instance.client.auth.currentUser?.id?? '', onBlock: _blockUser, onUnblock: _unblockUser);
              },
            ),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _reportsStream(),
              builder: (context, snap) {
                final reports = snap.data?? [];
                return _ReportsTab(reports: reports, onReply: (id, uid, reply) => _replyReport(id, uid, reply, banUser: false), onBanAndReply: (id, uid, reply) => _replyReport(id, uid, reply, banUser: true), getUserMini: _getUserMini);
              },
            ),
            _PendingRoomsTab(rooms: _pendingRooms, onApprove: _approveRoom),
            _ContactTab(phone: adminPhone, email: adminEmail, message: adminMessage, onEdit: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditContactScreen()));
              _loadStatic();
            }),
          ]),
    );
  }
}

class _UsersTab extends StatelessWidget {
  final List<UserModel> users; final String myId;
  final Function(String, String) onBlock; final Function(String, String) onUnblock;
  const _UsersTab({required this.users, required this.myId, required this.onBlock, required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i];
        final isAdmin = u.role == 'admin';
        final isBlocked = u.isBlocked;
        final isMe = u.id == myId;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isBlocked? AppColors.danger.withOpacity(0.4) : AppColors.glassBorder),
          ),
          child: Row(children: [
            UserAvatar(url: u.avatarUrl, name: u.username, size: 46, isOnline: u.isOnline),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.username, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(u.email?? '', style: const TextStyle(color: AppColors.textSub, fontSize: 12), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.bgCard2, borderRadius: BorderRadius.circular(20)),
                  child: Text(isAdmin? 'مدير' : 'عضو', style: TextStyle(color: isAdmin? AppColors.primary : AppColors.textSub, fontSize: 11, fontWeight: FontWeight.w600))),
                if (isBlocked)...[ const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: const Text('محظور', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600))),
                ],
              ]),
            ])),
            if (!isMe)
              PopupMenuButton<String>(
                onSelected: (v) { if (v == 'block') onBlock(u.id, u.username); else if (v == 'unblock') onUnblock(u.id, u.username); },
                itemBuilder: (_) => [ PopupMenuItem(value: isBlocked? 'unblock' : 'block',
                  child: Text(isBlocked? 'إلغاء الحظر' : 'حظر نهائي', style: TextStyle(color: isBlocked? AppColors.success : AppColors.danger))) ],
                child: const Icon(Icons.more_vert_rounded, color: AppColors.textSub),
              ),
          ]),
        );
      },
    );
  }
}

class ReportCard extends StatefulWidget {
  final Map<String, dynamic> report;
  final Future<Map<String, dynamic>?> Function(String) getUserMini;
  final Function(String, String, String) onReply;
  final Function(String, String, String) onBanAndReply;
  const ReportCard({super.key, required this.report, required this.onReply, required this.onBanAndReply, required this.getUserMini});
  @override State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard> {
  @override
  Widget build(BuildContext context) {
    final reporterId = widget.report['reporter_id'] as String?;
    final reportedId = widget.report['reported_id'] as String?;
    final reason = widget.report['reason']?? 'بدون سبب';
    final status = widget.report['status']?? 'new';
    final createdAt = widget.report['created_at']?.toString()?? '';
    final theme = Theme.of(context);

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        reporterId!= null? widget.getUserMini(reporterId) : Future.value(null),
        reportedId!= null? widget.getUserMini(reportedId) : Future.value(null),
      ]),
      builder: (context, snap) {
        final reporter = snap.data?[0]?? {};
        final reported = snap.data?[1]?? {};
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              UserAvatar(url: reported['avatar_url'], name: reported['username']?? 'مستخدم', size: 44),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(reported['username']?? 'مستخدم', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('بلاغ من: ${reporter['username']?? 'مجهول'}', style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(status, style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 10),
            Text(reason, style: const TextStyle(color: AppColors.textSub, fontSize: 13, height: 1.5)),
            if (createdAt.isNotEmpty)...[
              const SizedBox(height: 4),
              Text(createdAt.length > 16? createdAt.substring(0, 16) : createdAt, style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => widget.onReply(widget.report['id'], reportedId?? '', 'تم رفض البلاغ'),
                icon: const Icon(Icons.visibility_off_rounded, size: 18),
                label: const Text('تجاهل'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => widget.onBanAndReply(widget.report['id'], reportedId?? '', 'تم حظر المستخدم بسبب البلاغ'),
                icon: const Icon(Icons.block_rounded, size: 18),
                label: const Text('حظر'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              )),
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
  final Function(String, String, String) onBanAndReply;
  final Future<Map<String, dynamic>?> Function(String) getUserMini;
  const _ReportsTab({required this.reports, required this.onReply, required this.onBanAndReply, required this.getUserMini});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) return const Center(child: Text('لا توجد بلاغات', style: TextStyle(color: AppColors.textSub)));
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: reports.length,
      itemBuilder: (_, i) => ReportCard(report: reports[i], onReply: onReply, onBanAndReply: onBanAndReply, getUserMini: getUserMini));
  }
}

class _PendingRoomsTab extends StatelessWidget {
  final List<Map<String, dynamic>> rooms;
  final Function(String, String) onApprove;
  const _PendingRoomsTab({required this.rooms, required this.onApprove});

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) return const Center(child: Text('لا توجد غرف معلقة', style: TextStyle(color: AppColors.textSub)));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rooms.length,
      itemBuilder: (_, i) {
        final r = rooms[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.glassBorder)),
          child: Row(children: [
            Expanded(child: Text(r['name']?? 'غرفة', style: const TextStyle(fontWeight: FontWeight.w700))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () => onApprove(r['id'], r['owner_id']?? ''),
              child: const Text('موافقة', style: TextStyle(color: Colors.white)),
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
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.glassBorder)),
          child: Column(children: [
            ListTile(leading: const Icon(Icons.phone_rounded, color: AppColors.primary), title: Text(phone.isEmpty? 'لا يوجد' : phone), subtitle: const Text('واتساب', style: TextStyle(color: AppColors.textSub))),
            const Divider(),
            ListTile(leading: const Icon(Icons.email_rounded, color: AppColors.primary), title: Text(email.isEmpty? 'لا يوجد' : email), subtitle: const Text('البريد', style: TextStyle(color: AppColors.textSub))),
            if (message.isNotEmpty)...[
              const Divider(),
              ListTile(leading: const Icon(Icons.message_rounded, color: AppColors.primary), title: Text(message)),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_rounded), label: const Text('تعديل معلومات التواصل')),
      ],
    );
  }
}
