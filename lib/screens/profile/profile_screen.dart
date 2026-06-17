import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _zodiacCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _avatarUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _whatsappCtrl.dispose();
    _birthDateCtrl.dispose();
    _zodiacCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final profile = auth.userProfile;
      if (profile!= null) {
        _usernameCtrl.text = profile['username']?? '';
        _bioCtrl.text = profile['bio']?? '';
        _whatsappCtrl.text = profile['whatsapp']?? '';
        _birthDateCtrl.text = profile['birth_date']?.toString().split(' ')[0]?? '';
        _zodiacCtrl.text = profile['zodiac']?? '';
        _avatarUrl = profile['avatar_url'];
      }
    } catch (_) {
      if (mounted) _showSnack('فشل تحميل البروفايل', false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final success = await context.read<AuthProvider>().updateProfile({
      'username': _usernameCtrl.text.trim(),
      'bio': _bioCtrl.text.trim(),
      'whatsapp': _whatsappCtrl.text.trim(),
      'birth_date': _birthDateCtrl.text.trim().isEmpty? null : _birthDateCtrl.text.trim(),
      'zodiac': _zodiacCtrl.text.trim(),
      'avatar_url': _avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      _showSnack(success? 'تم تحديث البروفايل بنجاح' : 'فشل تحديث البروفايل', success);
      if (success) Navigator.pop(context, true);
    }
    if (mounted) setState(() => _isSaving = false);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: success? Colors.green : Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('تعديل البروفايل', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [if (!_isSaving) TextButton(onPressed: _updateProfile, child: const Text('حفظ', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.w700)))],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGrad),
        child: _isLoading
       ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, MediaQuery.of(context).padding.bottom + 20),
                  child: Form(
                    key: _formKey,
                    child: Column(children: [
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _isUploading? null : _uploadAvatar,
                        child: Stack(alignment: Alignment.center, children: [
                          Container(
                            width: 120, height: 120,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 3)),
                            child: ClipOval(
                              child: _avatarUrl!= null
                             ? CachedNetworkImage(imageUrl: _avatarUrl!, fit: BoxFit.cover, placeholder: (c, u) => Container(color: AppColors.bgCard2), errorWidget: (c, u, e) => Container(color: AppColors.bgCard2, child: const Icon(Icons.person, size: 60, color: AppColors.white)))
                                  : Container(color: AppColors.bgCard2, child: const Icon(Icons.person, size: 60, color: AppColors.white)),
                            ),
                          ),
                          if (_isUploading) Container(width: 120, height: 120, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54), child: const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
                          Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.bg, width: 2)), child: const Icon(Icons.camera_alt, color: AppColors.white, size: 20))),
                        ]),
                      ),
                      const SizedBox(height: 32),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: double.infinity, padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: AppColors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.white.withOpacity(0.2), width: 1)),
                            child: Column(children: [
                              _field(_usernameCtrl, 'اسم المستخدم', Icons.person_outline_rounded, validator: (v) => v == null || v.trim().isEmpty? 'ادخل اسم المستخدم' : v.length < 3? 'الاسم قصير جداً' : null),
                              const SizedBox(height: 16),
                              _field(_bioCtrl, 'النبذة التعريفية', Icons.info_outline_rounded, maxLines: 3, maxLength: 150),
                              const SizedBox(height: 16),
                              _field(_whatsappCtrl, 'رقم الواتساب', Icons.phone_outlined, keyboardType: TextInputType.phone),
                              const SizedBox(height: 16),
                              _field(_birthDateCtrl, 'تاريخ الميلاد (مثال: 1995-06-15)', Icons.cake_outlined),
                              const SizedBox(height: 16),
                              _field(_zodiacCtrl, 'البرج', Icons.star_outline_rounded),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving? null : _updateProfile,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                          child: _isSaving? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2)) : const Text('حفظ التغييرات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1, int? maxLength, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl, maxLines: maxLines, maxLength: maxLength, keyboardType: keyboardType, validator: validator,
      style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
        prefixIcon: Icon(icon, color: AppColors.textSub, size: 20),
        filled: true, fillColor: AppColors.bgCard2.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.glassBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.glassBorder.withOpacity(0.5))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        counterStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 11),
      ),
    );
  }
}
