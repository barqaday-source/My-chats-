import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _loading = false;
  late bool _isOwner;
  String? _avatarUrl;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _isOwner = user.id == widget.room.ownerId;
    _nameController.text = widget.room.name;
    _descController.text = widget.room.description ?? '';
    _avatarUrl = widget.room.avatarUrl;
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
      final bytes = await _pickedImage!.readAsBytes();
      final path = 'rooms/${widget.room.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage.from('room_avatars').uploadBinary(
        path, bytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      return _supabase.storage.from('room_avatars').getPublicUrl(path);
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
        avatarUrl: newAvatar,
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
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('حذف الغرفة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
        content: const Text('هل أنت متأكد؟ سيتم حذف الغرفة نهائياً مع كل الرسائل.',
          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal'))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger))),
        ],
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
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('مغادرة الغرفة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
        content: const Text('هل تريد مغادرة الغرفة؟',
          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal'))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('مغادرة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger))),
        ],
      ),
    );
    if (confirm == true) {
      await _roomService.leaveRoom(widget.room.id, user.id);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title: const Text('إعدادات الغرفة', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGrad),
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_isOwner) ...[
                  Center(
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundImage: _pickedImage != null
                              ? FileImage(_pickedImage!)
                              : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null) as ImageProvider?,
                            child: _pickedImage == null && _avatarUrl == null
                              ? const Icon(Icons.camera_alt_rounded, size: 32)
                              : null,
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.edit, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('معلومات الغرفة'),
                  const SizedBox(height: 12),
                  _buildTextField(controller: _nameController, label: 'اسم الغرفة', icon: Icons.badge_rounded),
                  const SizedBox(height: 16),
                  _buildTextField(controller: _descController, label: 'وصف الغرفة', icon: Icons.description_rounded, maxLines: 3),
                  const SizedBox(height: 24),
                  _buildButton(label: 'حفظ التغييرات', icon: Icons.save_rounded, color: AppColors.primary, onTap: _saveChanges),
                  const SizedBox(height: 32),
                  _buildButton(label: 'حذف الغرفة', icon: Icons.delete_forever_rounded, color: AppColors.danger, onTap: _deleteRoom),
                ] else ...[
                  if (_avatarUrl != null)
                    Center(child: CircleAvatar(radius: 48, backgroundImage: NetworkImage(_avatarUrl!))),
                  const SizedBox(height: 16),
                  _buildInfoTile('اسم الغرفة', widget.room.name),
                  const SizedBox(height: 12),
                  _buildInfoTile('الوصف', widget.room.description ?? 'لا يوجد'),
                  const SizedBox(height: 32),
                  _buildButton(label: 'مغادرة الغرفة', icon: Icons.exit_to_app_rounded, color: AppColors.danger, onTap: _leaveRoom),
                ],
              ],
            ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title,
    style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700));

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.glassBorder)),
      child: TextField(
        controller: controller, maxLines: maxLines,
        style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.glassBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _buildButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontFamily: 'Tajawal', color: color, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
