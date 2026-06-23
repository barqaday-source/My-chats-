import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_snackbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _zodiacCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime? _birthDate;
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() { super.initState(); _loadProfile(); }

  @override
  void dispose() {
    _usernameCtrl.dispose(); _bioCtrl.dispose();
    _whatsappCtrl.dispose(); _zodiacCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final profile = await supabase.from('profiles').select().eq('id', userId).maybeSingle();
      if (profile != null && mounted) {
        _usernameCtrl.text = profile['username'] ?? '';
        _bioCtrl.text = profile['bio'] ?? '';
        _whatsappCtrl.text = profile['whatsapp'] ?? '';
        _zodiacCtrl.text = profile['zodiac'] ?? '';
        _avatarUrl = profile['avatar_url'];
        final birth = profile['birth_date'];
        if (birth != null) {
          try { _birthDate = DateTime.parse(birth.toString()); } catch (_) {}
        }
      }
    } catch (_) {
      if (mounted) _showSnack('فشل تحميل البروفايل', false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: now,
      locale: const Locale('ar'),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final username = _usernameCtrl.text.trim();
      final data = {
        'username': username,
        'bio': _bioCtrl.text.trim(),
        'whatsapp': _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
        'birth_date': _birthDate == null ? null : 
          '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2,'0')}-${_birthDate!.day.toString().padLeft(2,'0')}',
        'zodiac': _zodiacCtrl.text.trim().isEmpty ? null : _zodiacCtrl.text.trim(),
        'avatar_url': _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await supabase.from('profiles').update(data).eq('id', userId);
      try {
        await supabase.from('room_members').update({'display_name': username}).eq('user_id', userId);
      } catch (_) {}
      try {
        await supabase.from('users').update({'username': username, 'avatar_url': _avatarUrl}).eq('id', userId);
      } catch (_) {}
      
      if (mounted) {
        _showSnack('تم تحديث البروفايل بنجاح', true);
      }
    } catch (e) {
      if (mounted) _showSnack('فشل تحديث البروفايل: $e', false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadAvatar() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
      if (image == null) return;
      setState(() => _isUploading = true);
      final userId = supabase.auth.currentUser!.id;
      final bytes = await image.readAsBytes();
      final ext = image.path.split('.').last;
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supabase.storage.from('avatars').uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
      final url = supabase.storage.from('avatars').getPublicUrl(fileName);
      setState(() => _avatarUrl = url);
    } catch (_) {
      if (mounted) _showSnack('فشل رفع الصورة', false);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnack(String msg, bool success) {
    showAppSnack(context, msg, success: success);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل البروفايل'),
        actions: [
          if (!_isSaving)
            TextButton(onPressed: _updateProfile, child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.w700)))
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(children: [
                  GestureDetector(
                    onTap: _isUploading ? null : _uploadAvatar,
                    child: Stack(alignment: Alignment.center, children: [
                      UserAvatar(
                        url: _avatarUrl,
                        name: _usernameCtrl.text.isEmpty ? '؟' : _usernameCtrl.text,
                        size: 110,
                        showBorder: true,
                      ),
                      if (_isUploading)
                        Container(width: 110, height: 110,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.4)),
                            child: const Center(child: CircularProgressIndicator())),
                      Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: theme.scaffoldBackgroundColor, width: 2)),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18))),
                    ]),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.glassBorder)),
                    child: Column(children: [
                      _field(_usernameCtrl, 'اسم المستخدم', Icons.person_outline_rounded,
                          validator: (v) => v == null || v.trim().isEmpty ? 'ادخل اسم المستخدم' : v.length < 3 ? 'الاسم قصير جداً' : null),
                      const SizedBox(height: 16),
                      _field(_bioCtrl, 'النبذة التعريفية', Icons.info_outline_rounded, maxLines: 3, maxLength: 150),
                      const SizedBox(height: 16),
                      _field(_whatsappCtrl, 'رقم الواتساب', Icons.phone_outlined, keyboardType: TextInputType.phone),
                      const SizedBox(height: 16),
                      TextFormField(
                        readOnly: true,
                        onTap: _pickBirthDate,
                        controller: TextEditingController(
                          text: _birthDate == null ? '' : '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2,'0')}-${_birthDate!.day.toString().padLeft(2,'0')}',
                        ),
                        decoration: const InputDecoration(
                          labelText: 'تاريخ الميلاد',
                          prefixIcon: Icon(Icons.cake_outlined),
                          suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _field(_zodiacCtrl, 'البرج', Icons.auto_awesome_rounded),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _updateProfile,
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('حفظ التغييرات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1, int? maxLength, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
