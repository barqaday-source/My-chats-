import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  UserModel? _user;
  bool _loading = true;
  bool _isBlockedByMe = false;
  bool _isAdmin = false;
  bool _isMod = false;

  @override
  void initState() {
    super.initState();
    _loadUserFullData();
  }

  Future<void> _loadUserFullData() async {
    setState(() => _loading = true);
    try {
      final me = context.read<AuthProvider>().user!;
      
      final res = await _supabase
         .from('users')
         .select()
         .eq('id', widget.userId)
         .single();
      _user = UserModel.fromJson(res);

      final blockRes = await _supabase
         .from('blocks')
         .select()
         .eq('blocker_id', me.id)
         .eq('blocked_id', widget.userId)
         .maybeSingle();
      _isBlockedByMe = blockRes!= null;

      final adminRes = await _supabase
         .from('admins')
         .select()
         .eq('user_id', widget.userId)
         .maybeSingle();
      _isAdmin = adminRes!= null;

      _isMod = _user?.role == 'moderator' || (_user?.isMod?? false);

    } catch (e) {
      debugPrint('Load user profile error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleBlock() async {
    final me = context.read<AuthProvider>().user!;
    if (me.id == widget.userId) return;

    try {
      if (_isBlockedByMe) {
        await _supabase
           .from('blocks')
           .delete()
           .eq('blocker_id', me.id)
           .eq('blocked_id', widget.userId);
      } else {
        await _supabase.from('blocks').insert({
          'blocker_id': me.id,
          'blocked_id': widget.userId,
        });
      }
      setState(() => _isBlockedByMe =!_isBlockedByMe);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isBlockedByMe? 'تم الحظر' : 'تم إلغاء الحظر')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل العملية')),
        );
      }
    }
  }

  Future<void> _reportUser() async {
    final textCtrl = TextEditingController();
    String reportType = 'spam';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (context, setDialogState) => Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: AppColors.textSub, borderRadius: BorderRadius.circular(2)),
                    ),
                    Text('إبلاغ عن ${_user!.username}',
                        style: const TextStyle(
                            fontFamily: 'Tajawal',
                            color: AppColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: reportType,
                      dropdownColor: AppColors.bgCard2,
                      style: const TextStyle(color: AppColors.white, fontFamily: 'Tajawal'),
                      decoration: InputDecoration(
                        labelText: 'نوع البلاغ',
                        labelStyle: const TextStyle(color: AppColors.textSub),
                        filled: true,
                        fillColor: AppColors.bgCard2,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'spam', child: Text('رسائل مزعجة')),
                        DropdownMenuItem(value: 'harassment', child: Text('تحرش أو تنمر')),
                        DropdownMenuItem(value: 'fake', child: Text('حساب وهمي')),
                        DropdownMenuItem(value: 'inappropriate', child: Text('محتوى غير لائق')),
                        DropdownMenuItem(value: 'other', child: Text('سبب آخر')),
                      ],
                      onChanged: (val) => setDialogState(() => reportType = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textCtrl,
                      style: const TextStyle(color: AppColors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'اكتب تفاصيل البلاغ...',
                        hintStyle: const TextStyle(color: AppColors.textSub),
                        filled: true,
                        fillColor: AppColors.bgCard2,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('إلغاء')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            onPressed: () async {
                              if (textCtrl.text.trim().isEmpty) return;
                              final me = context.read<AuthProvider>().user!;
                              await _supabase.from('reports').insert({
                                'reporter_id': me.id,
                                'reported_id': _user!.id,
                                'reason': '[$reportType] ${textCtrl.text.trim()}',
                                'status': 'pending',
                              });
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم إرسال البلاغ للإدارة')),
                                );
                              }
                            },
                            child: const Text('إرسال'),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;
    final isMe = me?.id == widget.userId;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('البروفايل',
            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
        actions: [
          if (!isMe && _user!= null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.white),
              color: AppColors.bgCard2,
              onSelected: (value) {
                if (value == 'block') _toggleBlock();
                if (value == 'report') _reportUser();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'block',
                  child: Text(_isBlockedByMe? 'إلغاء الحظر' : 'حظر المستخدم'),
                ),
                const PopupMenuItem(value: 'report', child: Text('إبلاغ')),
              ],
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGrad),
        child: SafeArea(
          bottom: false,
          child: _loading
             ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _user == null
                 ? const Center(
                      child: Text('تعذر تحميل البيانات',
                          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                      child: Column(children: [
                        _buildProfileHeader(),
                        const SizedBox(height: 24),
                        _buildInfoCard(),
                        if (!isMe)...[
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                        ]
                      ]),
                    ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(children: [
      UserAvatar(
        url: _user!.avatarUrl,
        name: _user!.username,
        size: 90,
        isOnline: _user!.isOnline,
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _user!.username,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (_isAdmin || _isMod)...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (_isAdmin? AppColors.primary : AppColors.accent).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isAdmin? '👑 مدير' : '🛡️ مشرف',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  color: _isAdmin? AppColors.primary : AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 4),
      Text(
        _user!.isOnline? 'متصل الآن' : 'غير متصل',
        style: TextStyle(
          fontFamily: 'Tajawal',
          color: _user!.isOnline? AppColors.online : AppColors.textSub,
          fontSize: 13,
        ),
      ),
    ]);
  }

  Widget _buildInfoCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_user!.bio!= null && _user!.bio!.isNotEmpty)...[
                _infoRow(Icons.info_outline_rounded, 'النبذة', _user!.bio!),
                const SizedBox(height: 16),
              ],
              if (_user!.birthDate!= null)...[
                _infoRow(Icons.cake_outlined, 'تاريخ الميلاد', _user!.birthDate?.toString().split(' ')[0]?? 'غير محدد'),
                const SizedBox(height: 16),
              ],
              if (_user!.zodiac!= null && _user!.zodiac!.isNotEmpty)...[
                _infoRow(Icons.auto_awesome_rounded, 'البرج', _user!.zodiac!),
                const SizedBox(height: 16),
              ],
              if (_user!.whatsapp!= null && _user!.whatsapp!.isNotEmpty)
                _infoRow(Icons.phone_rounded, 'واتساب', _user!.whatsapp!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isBlockedByMe? AppColors.textSub : AppColors.danger,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _toggleBlock,
            icon: Icon(_isBlockedByMe? Icons.lock_open_rounded : Icons.block_rounded, size: 20),
            label: Text(_isBlockedByMe? 'إلغاء الحظر' : 'حظر',
                style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _reportUser,
            icon: const Icon(Icons.flag_rounded, size: 20),
            label: const Text('إبلاغ',
                style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
