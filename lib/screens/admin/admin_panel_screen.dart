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
  String _myRole = 'user';

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تسجيل الدخول', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      final userData = await _sb
         .from(SupabaseConfig.tUsers)
         .select('role, is_mod')
         .eq('id', user.id)
         .single();

      final role = userData['role'] as String?? 'user';
      final isMod = userData['is_mod'] as bool?? false;
      _myRole = role;

      if (role == 'admin' || role == 'moderator' || isMod) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل التحقق من الصلاحية', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
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
      if (contactData!= null) {
        adminPhone = contactData['whatsapp_number']?? '';
        adminEmail = contactData['contact_email']?? '';
        adminMessage = contactData['support_message']?? '';
      }
    } catch (e) {
      debugPrint('Load admin data error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحميل البيانات', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _blockUser(String uid, String username) async {
    try {
      await _sb.from(SupabaseConfig.tUsers)
         .update({'is_blocked': true, 'blocked_at': DateTime.now().toIso8601String()})
         .eq('id', uid);

      await _notifSvc.sendNotification(NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: uid,
        title: 'تم حظر حسابك',
        body: 'تم حظر حسابك من قبل الإدارة. للمراجعة تواصل معنا.',
        type: 'account_blocked',
        createdAt: DateTime.now(),
      ));

      await _notifSvc.showNotification('تم الحظر', 'تم حظر $username');
      _load();
    } catch (e) {
      debugPrint('Block user error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الطلب', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _unblockUser(String uid, String username) async {
    try {
      await _sb.from(SupabaseConfig.tUsers)
         .update({'is_blocked': false, 'blocked_at': null})
         .eq('id', uid);

      await _notifSvc.sendNotification(NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: uid,
        title: 'تم إلغاء الحظر',
        body: 'تم إلغاء حظر حسابك. يمكنك الآن استخدام التطبيق.',
        type: 'account_unblocked',
        createdAt: DateTime.now(),
      ));

      await _notifSvc.showNotification('تم إلغاء الحظر', 'تم إلغاء حظر $username');
      _load();
    } catch (e) {
      debugPrint('Unblock user error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الطلب', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _replyReport(String reportId, String userId, String reply) async {
    try {
      await _sb.from(SupabaseConfig.tReports)
         .update({'reply': reply, 'status': 'replied', 'updated_at': DateTime.now().toIso8601String()})
         .eq('id', reportId);

      await _notifSvc.sendNotification(NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: 'رد على بلاغك',
        body: reply,
        type: 'report_reply',
        createdAt: DateTime.now(),
      ));
      await _notifSvc.showNotification('تم الرد', 'تم الرد على البلاغ بنجاح');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الطلب', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _changeRole(String userId, String role) async {
    try {
      await _sb.from(SupabaseConfig.tUsers)
         .update({'role': role, 'is_mod': role == 'admin' || role == 'moderator'})
         .eq('id', userId);
      await _notifSvc.showNotification('تم التحديث', 'تم تغيير الصلاحية بنجاح');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الطلب', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _approveRoom(String roomId, String ownerId) async {
    try {
      await _sb.from(SupabaseConfig.tRooms)
         .update({'is_approved': true})
         .eq('id', roomId);

      await _notifSvc.sendNotification(NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: ownerId,
        title: 'تمت الموافقة على غرفتك',
        body: 'غرفتك الآن ظاهرة لجميع المستخدمين',
        type: 'room_approved',
        createdAt: DateTime.now(),
      ));

      await _notifSvc.showNotification('تمت الموافقة', 'تم تفعيل الغرفة بنجاح');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الطلب', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin &&!_loading) {
      return const Scaffold(
        body: Center(child: Text('ليس لديك صلاحية', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text))),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGrad),
        child: SafeArea(
          child: Column(children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
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
                          myRole: _myRole,
                          myId: Supabase.instance.client.auth.currentUser?.id?? '',
                          onBlock: _blockUser,
                          onUnblock: _unblockUser,
                          onChangeRole: _changeRole),
                      _ReportsTab(reports: _reports, onReply: _replyReport),
                      _PendingRoomsTab(rooms: _pendingRooms, onApprove: _approveRoom),
                      _ContactTab(
                        phone: adminPhone,
                        email: adminEmail,
                        message: adminMessage,
                        onEdit: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EditContactScreen()),
                          );
                          _load();
                        },
                      ),
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
  final String myRole;
  final String myId;
  final Function(String, String) onBlock;
  final Function(String, String) onUnblock;
  final Function(String, String) onChangeRole;

  const _UsersTab({
    required this.users,
    required this.myRole,
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
        final isMod = u.role == 'moderator' || u.isMod;
        final isBlocked = u.isBlocked;
        final isMe = u.id == myId;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isBlocked? AppColors.danger.withOpacity(0.1) : AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isBlocked? AppColors.danger.withOpacity(0.5) : AppColors.glassBorder,
              width: 0.8,
            ),
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
                      color: (isAdmin? AppColors.primary : isMod? AppColors.accent : AppColors.bgCard2).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAdmin? 'مدير' : isMod? 'مشرف' : 'عضو',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: isAdmin? AppColors.primary : isMod? AppColors.accent : AppColors.textSub,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (isBlocked)...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('محظور', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger, fontSize: 10)),
                    ),
                  ],
                ]),
              ]),
            ),
            // الزر يبقى دائماً إلا على نفسك
            if (!isMe)
              PopupMenuButton<String>(
                color: AppColors.bgCard2,
                onSelected: (v) {
                  if (v == 'block') onBlock(u.id, u.username);
                  else if (v == 'unblock') onUnblock(u.id, u.username);
                  else onChangeRole(u.id, v);
                },
                itemBuilder: (_) {
                  List<PopupMenuEntry<String>> items = [];

                  // الأدمن: يقدر يسوي كلشي إلا يحظر أدمن ثاني
                  if (myRole == 'admin') {
                    if (!isAdmin) {
                      items.add(const PopupMenuItem(value: 'admin', child: Text('جعله مدير', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.primary))));
                    }
                    if (!isMod &&!isAdmin) {
                      items.add(const PopupMenuItem(value: 'moderator', child: Text('جعله مشرف', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.accent))));
                    }
                    if (isMod || isAdmin) {
                      items.add(const PopupMenuItem(value: 'user', child: Text('إزالة الإشراف', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text))));
                    }
                    if (!isAdmin) { // الأدمن ما يحظر أدمن
                      items.add(PopupMenuItem(
                        value: isBlocked? 'unblock' : 'block',
                        child: Text(
                          isBlocked? 'إلغاء الحظر' : 'حظر نهائي',
                          style: TextStyle(fontFamily: 'Tajawal', color: isBlocked? AppColors.success : AppColors.danger),
                        ),
                      ));
                    }
                  }

                  // المشرف: بس يحظر أعضاء عاديين
                  if (myRole == 'moderator') {
                    if (!isAdmin &&!isMod) {
                      items.add(PopupMenuItem(
                        value: isBlocked? 'unblock' : 'block',
                        child: Text(
                          isBlocked? 'إلغاء الحظر' : 'حظر المستخدم',
                          style: TextStyle(fontFamily: 'Tajawal', color: isBlocked? AppColors.success : AppColors.danger),
                        ),
                      ));
                    }
                  }

                  return items;
                },
                child: const Icon(Icons.more_vert_rounded, color: AppColors.textSub),
              ),
          ]),
        );
      },
    );
  }
}

class _ReportsTab extends StatelessWidget {
  final List<Map<String, dynamic>> reports;
  final Function(String, String, String) onReply;
  const _ReportsTab({required this.reports, required this.onReply});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) return const Center(child: Text('لا توجد بلاغات', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: reports.length,
      itemBuilder: (_, i) {
        final r = reports[i];
        final reporter = r['reporter'] as Map<String, dynamic>?;
        final reported = r['reported'] as Map<String, dynamic>?;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning.withOpacity(0.3), width: 0.8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.flag_rounded, color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('المبلغ عليه: ${reported?['username']?? 'مجهول'}',
                    style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: r['status'] == 'replied'? AppColors.success.withOpacity(0.15) : AppColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r['status'] == 'replied'? 'تم الرد' : 'جديد',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: r['status'] == 'replied'? AppColors.success : AppColors.warning,
                    fontSize: 10,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text('من: ${reporter?['username']?? 'مجهول'}',
                style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 11)),
            const SizedBox(height: 8),
            Text(r['reason']?? '', style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 13, height: 1.4)),
            if (r['reply']!= null)...[
              const Divider(color: AppColors.divider, height: 16),
              Text('الرد: ${r['reply']}', style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.success, fontSize: 12)),
            ],
            if (r['status']!= 'replied')...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () => _replyDialog(context, r['id'], r['reporter_id']),
                  icon: const Icon(Icons.reply_rounded, size: 16),
                  label: const Text('رد على البلاغ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ]),
        );
      },
    );
  }

  void _replyDialog(BuildContext ctx, String reportId, String userId) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('الرد على البلاغ', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text),
          decoration: const InputDecoration(hintText: 'اكتب ردك هنا...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub))),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                onReply(reportId, userId, ctrl.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('إرسال الرد', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
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
      return const Center(
          child: Text('لا توجد طلبات غرف معلقة',
              style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rooms.length,
      itemBuilder: (_, i) {
        final r = rooms[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.meeting_room_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(r['name']?? 'غرفة بدون اسم',
                    style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            Text('الوصف: ${r['description']?? 'لا يوجد وصف'}',
                style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 12)),
            const SizedBox(height: 4),
            Text('أنشأها: ${r['created_by_name']?? r['created_by']?? 'مجهول'}',
                style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 11)),
            const SizedBox(height: 12),
            Row(children: [
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: () => onApprove(r['id'].toString(), r['created_by'].toString()),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('موافقة وتفعيل', style: TextStyle(fontFamily: 'Tajawal')),
              ),
            ]),
          ]),
        );
      },
    );
  }
}

class _ContactTab extends StatelessWidget {
  final String phone;
  final String email;
  final String message;
  final VoidCallback onEdit;
  const _ContactTab({
    required this.phone,
    required this.email,
    required this.message,
    required this.onEdit,
  });

  Future<void> _launchWhatsApp(BuildContext context) async {
    if (phone.isEmpty) return;
    final text = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$phone?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تأكد من تثبيت واتساب', style: TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    }
  }

  Future<void> _launchEmail(BuildContext context) async {
    if (email.isEmpty) return;
    final subject = Uri.encodeComponent('دعم تطبيق CChat');
    final body = Uri.encodeComponent(message);
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد تطبيق بريد', style: TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.support_agent_rounded, size: 80, color: AppColors.primary),
        const SizedBox(height: 16),
        const Text('تواصل مع الإدارة',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('للاستفسارات أو المراجعة على الحظر',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 14)),
        const SizedBox(height: 32),
        if (phone.isNotEmpty)
          _ContactCard(
            icon: Icons.chat_rounded,
            title: 'واتساب',
            subtitle: '+$phone',
            color: Colors.green,
            onTap: () => _launchWhatsApp(context),
          ),
        const SizedBox(height: 12),
        if (email.isNotEmpty)
          _ContactCard(
            icon: Icons.email_rounded,
            title: 'البريد الإلكتروني',
            subtitle: email,
            color: Colors.blue,
            onTap: () => _launchEmail(context),
          ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('تعديل معلومات التواصل', style: TextStyle(fontFamily: 'Tajawal')),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: const Text(
            'ملاحظة: يتم مراجعة طلبات إلغاء الحظر خلال 24-48 ساعة. يرجى إرسال اسم المستخدم + سبب طلب المراجعة.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 12)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSub, size: 16),
        ]),
      ),
    );
  }
}
