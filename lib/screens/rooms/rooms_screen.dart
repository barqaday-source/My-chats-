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
  @override State<RoomsScreen> createState() => _RoomsScreenState();
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
      return list.where((r) => r.isActive && r.onlineCount > 0).toList();
    }
    return list;
  }

  Future<void> _openRoom(RoomModel room) async {
    if (!room.isActive) {
      _snack('الغرفة مغلقة حالياً', false);
      return;
    }
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
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: AppColors.glassBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
                    const Text('إنشاء غرفة جديدة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    _dialogField(nameCtrl, 'اسم الغرفة *', Icons.meeting_room_outlined),
                    const SizedBox(height: 12),
                    _dialogField(descCtrl, 'وصف الغرفة (اختياري)', Icons.description_outlined, maxLines: 2),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, 
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
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
                            createdAt: DateTime.now(),
                            isActive: true, // الغرفة تبدأ مفتوحة
                            onlineCount: 0,
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
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
          prefixIcon: Icon(icon, color: AppColors.textSub),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
        // الهيدر
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            const Expanded(child: Text('الغرف', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w800))),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.glass,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder, width: 0.5)
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 22), 
                    onPressed: () => _showCreateRoom(context), 
                    padding: const EdgeInsets.all(8), 
                    constraints: const BoxConstraints()
                  ),
                ),
              ),
            ),
          ]),
        ),
        // البحث
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.glassBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder, width: 0.5),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSub, size: 20),
                    hintText: 'ابحث عن غرفة...', 
                    hintStyle: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
        ),
        // التابات
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _tabs.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200), 
                margin: const EdgeInsets.only(right: 8), 
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: _tab == i? AppColors.primary : AppColors.glassBg, 
                  borderRadius: BorderRadius.circular(20), 
                  border: Border.all(color: _tab == i? AppColors.primaryDark : AppColors.glassBorder, width: 0.5),
                  boxShadow: _tab == i? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 8)] : null,
                ),
                child: Text(_tabs[i], style: TextStyle(fontFamily: 'Tajawal', color: _tab == i? Colors.white : AppColors.textSub, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // القائمة
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
                          ElevatedButton.icon(
                            onPressed: () => _showCreateRoom(context), 
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary, 
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ), 
                            icon: const Icon(Icons.add_rounded, size: 18), 
                            label: const Text('أنشئ أول غرفة', style: TextStyle(fontFamily: 'Tajawal'))
                          ),
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

    return GestureDetector(
      onTap: onEnter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05), 
              blurRadius: 15, 
              offset: const Offset(0, 4)
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: AppColors.glassBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // صورة خلفية الغرفة كبيرة
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16/9,
                        child: room.imageUrl!= null && room.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                                imageUrl: room.imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _roomPlaceholder(),
                              )
                            : _roomPlaceholder(),
                      ),
                      // طبقة تعتيم
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                            ),
                          ),
                        ),
                      ),
                      
                      // أيقونة قفل صغيرة إذا الغرفة مغلقة
                      if (!room.isActive)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_rounded, 
                              color: Colors.white, 
                              size: 16
                            ),
                          ),
                        ),

                      // صورة صاحب الغرفة + الاسم
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: room.ownerAvatar?? '',
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                imageBuilder: (context, imageProvider) => CircleAvatar(
                                  radius: 18,
                                  backgroundImage: imageProvider,
                                ),
                                errorWidget: (_, __, ___) => CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.primary,
                                  child: Text(
                                    room.ownerName.isNotEmpty? room.ownerName[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('المدير', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white70, fontSize: 10)),
                                Text(
                                  room.ownerName,
                                  style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // أيقونة الإعدادات للمالك
                      if (isOwner)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              final changed = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => RoomSettingsScreen(room: room)),
                              );
                              if (changed == true) onSettingsChanged?.call();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.settings_rounded, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  // معلومات الغرفة
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            color: AppColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (room.description!= null && room.description!.isNotEmpty)...[
                          const SizedBox(height: 6),
                          Text(
                            room.description!,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: AppColors.textSub,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // حالة الغرفة - نشطة/مغلقة
                            StreamBuilder<List<Map<String, dynamic>>>(
                              stream: supabase
                              .from('room_members')
                              .stream(primaryKey: ['id'])
                              .eq('room_id', room.id)
                              .map((rows) => rows.where((m) => m['is_online'] == true).toList()),
                              initialData: const [],
                              builder: (context, snap) {
                                final onlineCount = snap.data?.length?? room.onlineCount;
                                final active = room.isActive && onlineCount > 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: active? AppColors.success.withOpacity(0.15) : AppColors.danger.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: active? AppColors.success : AppColors.danger, 
                                      width: 0.5
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: active? AppColors.success : AppColors.danger,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                      !room.isActive? 'مغلقة' : active? '$onlineCount متصل' : 'غير نشطة',
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          color: active? AppColors.success : AppColors.danger,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            // سهم > للدخول
                            Icon(
                              Icons.chevron_left_rounded, 
                              color: room.isActive? AppColors.primary : AppColors.textSub, 
                              size: 24
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roomPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.3), AppColors.primaryDark.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.meeting_room_rounded, color: AppColors.primary, size: 48),
      ),
    );
  }
}
