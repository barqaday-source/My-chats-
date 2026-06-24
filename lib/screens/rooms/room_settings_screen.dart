import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/room_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/room_service.dart';
import '../../widgets/app_snackbar.dart';

class RoomSettingsScreen extends StatefulWidget {
  final RoomModel room;
  const RoomSettingsScreen({super.key, required this.room});

  @override
  State<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends State<RoomSettingsScreen> {
  final _roomService = RoomService();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _loading = false;
  late bool _isOwner;
  String? _avatarUrl;
  File? _pickedImage;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _isOwner = user.id == widget.room.ownerId;
    _nameController.text = widget.room.name;
    _descController.text = widget.room.description ?? '';
    _avatarUrl = widget.room.imageUrl; // غيّر avatarUrl لـ imageUrl
    _isActive = widget.room.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (!_isOwner) return;
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null) return;
    setState(() => _pickedImage = File(xfile.path));
  }

  Future<String?> _uploadAvatar() async {
    if (_pickedImage == null) return _avatarUrl;
    try {
      return await _roomService.uploadRoomImage(_pickedImage!, widget.room.id);
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل رفع الصورة: $e', success: false);
      return _avatarUrl;
    }
  }

  Future<void> _saveChanges() async {
    if (!_isOwner) return;
    if (_nameController.text.trim().isEmpty) {
      showAppSnack(context, 'اسم الغرفة مطلوب', success: false);
      return;
    }

    setState(() => _loading = true);
    try {
      final newAvatar = await _uploadAvatar();
      final updatedRoom = widget.room.copyWith(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        imageUrl: newAvatar, // غيّر avatarUrl لـ imageUrl
        isActive: _isActive,
      );
      await _roomService.updateRoom(updatedRoom);
      if (mounted) {
        showAppSnack(context, 'تم حفظ التغييرات', success: true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل الحفظ: $e', success: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteRoom() async {
    if (!_isOwner) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AlertDialog(
            backgroundColor: AppColors.glassBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('حذف الغرفة نهائياً', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger, fontWeight: FontWeight.w700)),
            content: const Text('هل أنت متأكد؟ سيتم حذف الغرفة وجميع الرسائل والأعضاء نهائياً ولا يمكن التراجع.',
              style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text, height: 1.5)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub))),
              TextButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف نهائي', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ),
    );
    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await _roomService.deleteRoom(widget.room.id);
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        if (mounted) {
          showAppSnack(context, 'فشل الحذف: $e', success: false);
          setState(() => _loading = false);
        }
      }
    }
  }

  Future<void> _leaveRoom() async {
    final user = context.read<AuthProvider>().user!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AlertDialog(
            backgroundColor: AppColors.glassBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('مغادرة الغرفة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
            content: const Text('هل تريد مغادرة الغرفة؟', style: TextStyle(fontFamily: 'Tajawal')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal'))),
              TextButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('مغادرة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ),
    );
    if (confirm == true) {
      await _roomService.leaveRoom(widget.room.id, user.id);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meId = supabase.auth.currentUser?.id;
    final isOwnProfile = meId == widget.room.ownerId;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('إعدادات الغرفة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        actions: [
          if (_isOwner && !_loading)
            TextButton(
              onPressed: _saveChanges,
              child: const Text('حفظ', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGrad),
        child: _loading
         ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              children: [
                // صورة الغرفة
                if (_isOwner) ...[
                  Center(
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _pickedImage!= null
                             ? Image.file(_pickedImage!, width: 120, height: 120, fit: BoxFit.cover)
                              : (_avatarUrl!= null
                               ? Image.network(_avatarUrl!, width: 120, height: 120, fit: BoxFit.cover)
                                : Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [AppColors.primary.withOpacity(0.3), AppColors.primaryDark.withOpacity(0.1)],
                                      ),
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded, size: 32, color: AppColors.textSub),
                                  )),
                          ),
                          Positioned(
                            bottom: 4, right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.edit, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else if (_avatarUrl!= null) ...[
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(_avatarUrl!, width: 120, height: 120, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // معلومات الغرفة - للمالك
                if (_isOwner) ...[
                  _buildField(controller: _nameController, label: 'اسم الغرفة', icon: Icons.badge_rounded),
                  const SizedBox(height: 16),
                  _buildField(controller: _descController, label: 'وصف الغرفة', icon: Icons.description_rounded, maxLines: 3),
                  const SizedBox(height: 16),

                  // حالة الغرفة - مفتوحة/مغلقة
                  _buildSwitch(
                    label: 'الغرفة مفتوحة',
                    subtitle: _isActive? 'يمكن للأعضاء الدخول' : 'مغلقة - لا يمكن الدخول',
                    icon: _isActive? Icons.lock_open_rounded : Icons.lock_rounded,
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),

                  const SizedBox(height: 32),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: 32),

                  // زر حذف خطر تحت
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _deleteRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded, size: 20),
                      label: const Text('حذف الغرفة نهائياً', style: TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ] else ...[
                  // معلومات للعضو العادي
                  _buildInfoTile('اسم الغرفة', widget.room.name),
                  const SizedBox(height: 12),
                  _buildInfoTile('الوصف', widget.room.description ?? 'لا يوجد'),
                  const SizedBox(height: 12),
                  _buildInfoTile('الحالة', widget.room.isActive? 'مفتوحة' : 'مغلقة'),
                  const SizedBox(height: 32),
                  _buildButton(label: 'مغادرة الغرفة', icon: Icons.exit_to_app_rounded, color: AppColors.danger, onTap: _leaveRoom),
                ],
              ],
            ),
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String label, required IconData icon, int maxLines = 1}) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: TextField(
        controller: controller, maxLines: maxLines,
        style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
          prefixIcon: Icon(icon, color: AppColors.textSub, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSwitch({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: value? AppColors.success : AppColors.danger, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.glassBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.glassBorder, width: 0.5),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _buildButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
