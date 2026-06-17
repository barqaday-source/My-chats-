import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../models/room_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/room_service.dart';
import 'room_chat_screen.dart';
import 'room_settings_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});
  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _svc = RoomService();
  List<RoomModel> _rooms = [];
  bool _loading = true;
  String _search = '';
  int _tab = 0;
  final _tabs = ['الكل', 'النشطة', 'الرسمية', 'المغلقة'];

  @override
  void initState() { super.initState(); _load(); }

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
    if (_search.isNotEmpty) list = list.where((r) => r.name.contains(_search)).toList();
    switch (_tab) {
      case 1: return list.where((r) => r.onlineCount > 0).toList();
      case 2: return list.where((r) => r.isOfficial).toList();
      case 3: return list.where((r) => r.isLocked).toList();
      default: return list;
    }
  }

  Future<void> _openRoom(RoomModel room) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => RoomChatScreen(room: room)));
    if (result == true) _load();
  }

  void _snack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: success? Colors.green : Colors.red),
    );
  }

  void _showCreateRoom(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: SafeArea(
            top: false,
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
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, foregroundColor: AppColors.white),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        _snack('فشل الطلب', false);
                        return;
                      }
                      final auth = ctx.read<AuthProvider>();
                      final room = RoomModel(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
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
                          Navigator.pop(ctx);
                          _snack('تم إنشاء الغرفة بنجاح', true);
                        }
                        _load();
                      } catch (_) {
                        if (ctx.mounted) _snack('فشل إنشاء الغرفة', false);
                      }
                    },
                    child: const Text('إنشاء الغرفة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
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
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true, fillColor: AppColors.bgCard2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.glassBorder, width
