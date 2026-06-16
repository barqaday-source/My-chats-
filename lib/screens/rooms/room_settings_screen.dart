import 'dart:io'; // ✅ أضفته: يحل خطأ File(picked.path)
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/room_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/user_avatar.dart';
import 'package:mychats/services/storage_service.dart';


class RoomSettingsScreen extends StatefulWidget {
  final RoomModel room;
  const RoomSettingsScreen({super.key, required this.room});

  @override
  State<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends State<RoomSettingsScreen> {
  final _chat = ChatService();
  final _storage = StorageService();
  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;
  bool _isLocked = false;
  bool _isSaving = false;
  bool _changed = false;
  String? _localImageUrl;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.room.name);
    _bioCtrl = TextEditingController(text: widget.room.description ?? '');
    _isLocked = widget.room.isLocked;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    setState(() => _uploadingImage = true);
    try {
      final url = await _storage.uploadRoomImage(widget.room.id, File(picked.path));
      if (!mounted) return;
      setState(() {
        _localImageUrl = url;
        _changed = true;
      });
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل رفع الصورة')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final updatedRoom = widget.room.copyWith(
        name: _nameCtrl.text.trim(),
        description: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        isLocked: _isLocked,
        imageUrl: _localImageUrl ?? widget.room.imageUrl,
        updatedAt: DateTime.now(),
      );
      await _chat.updateRoom(updatedRoom);
      _changed = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التغييرات')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Save room error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل حفظ التغييرات')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('حذف الغرفة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger)),
        content: const Text('هل أنت متأكد؟ لا يمكن التراجع عن هذا الإجراء.',
            style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _chat.deleteRoom(widget.room.id);
        if (mounted) {
          Navigator.pop(context, true);
          Navigator.pop(context, true);
        }
      } catch (e) {
        debugPrint('Delete room error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل حذف الغرفة')),
          );
        }
      }
    }
  }

  void _showMembers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(color: AppColors.textSub, borderRadius: BorderRadius.circular(2)),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('أعضاء الغرفة',
                      style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: StreamBuilder<List<UserModel>>(
                    stream: _chat.getRoomMembers(widget.room.id),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                      }
                      if (snap.hasError || !snap.hasData) {
                        return const Center(
                            child: Text('فشل تحميل الأعضاء',
                                style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)));
                      }
                      final members = snap.data!;
                      return ListView.builder(
                        controller: controller,
                        itemCount: members.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: UserAvatar(
                              url: members[i].avatarUrl,
                              name: members[i].username,
                              size: 40,
                              isOnline: members[i].isOnline),
                          title: Text(members[i].username,
                              style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
                          trailing: members[i].id == widget.room.ownerId
                              ? const Icon(Icons.star_rounded, color: AppColors.warning, size: 20)
                              : IconButton(
                                  icon: const Icon(Icons.block_rounded, color: AppColors.danger, size: 20),
                                  onPressed: () {
                                    _chat.removeRoomMember(widget.room.id, members[i].id);
                                  },
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user; // ✅ شلنا ! عشان ما يكرش لو الجلسة انتهت
    final isOwner = user?.id == widget.room.ownerId;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.bgCard,
          title: const Text('إعدادات الغرفة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
          actions: [
            if (isOwner)
              TextButton(
                onPressed: _isSaving ? null : _saveChanges,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Text('حفظ',
                        style: TextStyle(fontFamily: 'Tajawal', color: AppColors.primary, fontSize: 16)),
              ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.bgGrad),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  children: [
                    _uploadingImage
                        ? Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.bgCard2,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                          )
                        : UserAvatar(
                            url: _localImageUrl ?? widget.room.imageUrl,
                            name: widget.room.name,
                            size: 80
                          ),
                    if (isOwner)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _uploadingImage ? null : _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded, color: AppColors.white, size: 18),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameCtrl,
                enabled: isOwner,
                style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'اسم الغرفة',
                  labelStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                  filled: true,
                  fillColor: AppColors.bgCard2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bioCtrl,
                enabled: isOwner,
                maxLines: 3,
                style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'وصف الغرفة',
                  labelStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                  filled: true,
                  fillColor: AppColors.bgCard2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              if (isOwner)
                SwitchListTile(
                  title: const Text('قفل الغرفة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
                  subtitle: const Text('لا يمكن للأعضاء الجدد الانضمام',
                      style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 12)),
                  value: _isLocked,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _isLocked = val),
                ),
              const Divider(color: AppColors.glassBorder, height: 32),
              ListTile(
                leading: const Icon(Icons.people_outline_rounded, color: AppColors.textSub),
                title: const Text('الأعضاء', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
                trailing: Text('${widget.room.memberCount}',
                    style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
                onTap: _showMembers,
              ),
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  title: const Text('حذف الغرفة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger)),
                  onTap: _deleteRoom,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
