import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/room_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/room_service.dart';
import '../../widgets/app_snackbar.dart';
import 'room_chat_screen.dart';
import 'room_settings_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});
  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _svc = RoomService();
  final supabase = Supabase.instance.client;
  List<RoomModel> _rooms = [];
  bool _loading = true;
  String _search = '';
  int _tab = 0;
  final _tabs = ['الكل', 'النشطة'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _rooms = await _svc.getRooms();
    } catch (_) {
      if (mounted) _snack('فشل تحميل الغرف', false);
    }
    if (mounted) setState(() => _loading = false);
  }

  List<RoomModel> _filtered() {
    var list = _rooms;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((r) => r.name.toLowerCase().contains(q)).toList();
    }
    if (_tab == 1) {
      return list.where((r) => r.onlineCount > 0).toList();
    }
    return list;
  }

  Future<void> _openRoom(RoomModel room) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => RoomChatScreen(room: room)));
    if (result == true) _load();
  }

  void _snack(String msg, bool success) => showAppSnack(context, msg, success: success);

  void _showCreateRoom(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogCtx) => Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 20,
            top: 20,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
                  const Text('إنشاء غرفة جديدة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  TextField(controller: nameCtrl, style: const TextStyle(color: AppColors.text), decoration: const InputDecoration(labelText: 'اسم الغرفة *', labelStyle: TextStyle(color: AppColors.textSub), prefixIcon: Icon(Icons.meeting_room_outlined, color: AppColors.textSub))),
                  const SizedBox(height: 12),
                  TextField(controller: descCtrl, maxLines: 2, style: const TextStyle(color: AppColors.text), decoration: const InputDecoration(labelText: 'وصف الغرفة (اختياري)', labelStyle: TextStyle(color: AppColors.textSub), prefixIcon: Icon(Icons.description_outlined, color: AppColors.textSub))),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          _snack('اسم الغرفة مطلوب', false);
                          return;
                        }
                        final auth = ctx.read<AuthProvider>();
                        final room = RoomModel(
                          id: '',
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim().isEmpty? null : descCtrl.text.trim(),
                          ownerId: auth.user!.id,
                          ownerName: auth.userProfile?['username']?? auth.user!.email?.split('@')[0]?? 'مجهول',
                          ownerAvatar: auth.userProfile?['avatar_url'],
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                          members: [auth.user!.id],
                        );
                        try {
                          await _svc.createRoom(room, auth.user!.id);
                          if (ctx.mounted) {
                            Navigator.pop(dialogCtx);
                            _snack('تم وصول الطلب للمدير', true);
                          }
                          _load();
                        } catch (e) {
                          if (ctx.mounted) _snack('فشل إنشاء الغرفة: $e', false);
                        }
                      },
                      child: const Text('إنشاء الغرفة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: AppColors.bgGrad),
    child: SafeArea(
      bottom: true,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            const Expanded(child: Text('الغرف', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w800))),
            Container(
              decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.glassBorder)),
              child: IconButton(icon: const Icon(Icons.add_rounded, color: AppColors.primaryDark, size: 22), onPressed: () => _showCreateRoom(context), padding: const EdgeInsets.all(8), constraints: const BoxConstraints()),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSub, size: 20),
              hintText: 'ابحث عن غرفة...', hintStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              filled: true, fillColor: AppColors.bgCard2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.8)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.8)),
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _tabs.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(color: _tab == i? AppColors.primary : AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: _tab == i? AppColors.primaryDark : AppColors.glassBorder, width: 0.8)),
                child: Text(_tabs[i], style: TextStyle(fontFamily: 'Tajawal', color: _tab == i? Colors.white : AppColors.textSub, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  onRefresh: _load, color: AppColors.primary,
                  child: Builder(builder: (_) {
                    final list = _filtered();
                    if (list.isEmpty) {
                      return ListView(children: [
                        SizedBox(height: 120, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.meeting_room_outlined, color: AppColors.textSub, size: 40),
                          const SizedBox(height: 8),
                          const Text('لا توجد غرف بعد', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 14)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(onPressed: () => _showCreateRoom(context), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('أنشئ أول غرفة', style: TextStyle(fontFamily: 'Tajawal'))),
                        ]))),
                      ]);
                    }
                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 80),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _RoomCard(room: list[i], onEnter: () => _openRoom(list[i]), onSettingsChanged: _load),
                    );
                  }),
                ),
        ),
      ]),
    ),
  );
}

class _RoomCard extends StatelessWidget {
  final RoomModel room;
  final VoidCallback onEnter;
  final VoidCallback? onSettingsChanged;
  const _RoomCard({required this.room, required this.onEnter, this.onSettingsChanged});

  @override
  Widget build(BuildContext context) {
    final isOwner = room.ownerId == context.read<AuthProvider>().user!.id;
    final supabase = Supabase.instance.client;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.cardTheme.color?? AppColors.bgCard,
        border: Border.all(color: AppColors.glassBorder, width: 0.8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة الغرفة - كبيرة وواضحة
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: room.imageUrl!= null && room.imageUrl!.isNotEmpty
                 ? CachedNetworkImage(
                      imageUrl: room.imageUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _roomPlaceholder(),
                    )
                  : _roomPlaceholder(),
            ),
            const SizedBox(width: 14),
            // معلومات الغرفة
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.name,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            color: AppColors.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOwner)
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            final changed = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => RoomSettingsScreen(room: room)),
                            );
                            if (changed == true) onSettingsChanged?.call();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.settings_rounded, size: 18, color: AppColors.textSub),
                          ),
                        ),
                    ],
                  ),
                  if (room.description!= null && room.description!.isNotEmpty)...[
                    const SizedBox(height: 4),
                    Text(
                      room.description!,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: AppColors.textSub,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // عداد الأعضاء الأونلاين - تصميم جديد
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: supabase
                           .from('room_members')
                           .stream(primaryKey: ['id'])
                           .eq('room_id', room.id)
                           .map((rows) => rows.where((m) => m['is_online'] == true).toList()),
                        initialData: const [],
                        builder: (context, snap) {
                          final onlineCount = snap.data?.length?? room.onlineCount;
                          final online = onlineCount > 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: online? AppColors.success.withOpacity(0.1) : AppColors.bgCard2,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: online? AppColors.success : AppColors.offline,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  online? '$onlineCount متصل' : 'غير نشطة',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    color: online? AppColors.success : AppColors.textSub,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Spacer(),
                      // زر الدخول
                      FilledButton(
                        onPressed: onEnter,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roomPlaceholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.meeting_room_rounded, color: AppColors.primary, size: 28),
    );
  }
}
