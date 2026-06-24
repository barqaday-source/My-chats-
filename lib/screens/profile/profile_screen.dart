import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final _countryCtrl = TextEditingController();
  final _statusCtrl = TextEditingController(); // جديد
  
  DateTime? _birthDate;
  String? _zodiac;
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() { super.initState(); _loadProfile(); }

  @override
  void dispose() {
    _usernameCtrl.dispose(); 
    _countryCtrl.dispose();
    _statusCtrl.dispose(); // جديد
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final profile = await supabase.from('profiles').select().eq('id', userId).maybeSingle();
      if (profile != null && mounted) {
        _usernameCtrl.text = profile['username'] ?? '';
        _countryCtrl.text = profile['country'] ?? '';
        _statusCtrl.text = profile['status'] ?? ''; // جديد
        _zodiac = profile['zodiac'];
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

  int get _age {
    if (_birthDate == null) return 0;
    final now = DateTime.now();
    int age = now.year - _birthDate!.year;
    if (now.month < _birthDate!.month || (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
      age--;
    }
    return age;
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
    if (_usernameCtrl.text.trim().isEmpty) {
      _showSnack('ادخل اسم المستخدم', false);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final username = _usernameCtrl.text.trim();
      final data = {
        'username': username,
        'country': _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
        'status': _statusCtrl.text.trim().isEmpty ? null : _statusCtrl.text.trim(), // جديد
        'birth_date': _birthDate == null ? null : 
          '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2,'0')}-${_birthDate!.day.toString().padLeft(2,'0')}',
        'zodiac': _zodiac,
        'avatar_url': _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await supabase.from('profiles').update(data).eq('id', userId);
      await supabase.from('room_members').update({'display_name': username}).eq('user_id', userId);
      
      if (mounted) {
        _showSnack('تم حفظ التغييرات', true);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('فشل الحفظ: $e', false);
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('تعديل الملف الشخصي', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                // الصورة
                Center(
                  child: GestureDetector(
                    onTap: _isUploading ? null : _uploadAvatar,
                    child: Stack(alignment: Alignment.center, children: [
                      UserAvatar(
                        url: _avatarUrl,
                        name: _usernameCtrl.text.isEmpty ? '؟' : _usernameCtrl.text,
                        size: 120,
                        showBorder: true,
                      ),
                      if (_isUploading)
                        Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.4)),
                          child: const Center(child: CircularProgressIndicator())
                        ),
                      Positioned(
                        bottom: 4, right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary, 
                            shape: BoxShape.circle, 
                            border: Border.all(color: AppColors.bg, width: 2)
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18)
                        )
                      ),
                    ]),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // خانة الحالة - جديدة تحت الصورة مباشرة
                _buildStatusField(),
                
                const SizedBox(height: 24),
                
                // الاسم
                _buildField(
                  controller: _usernameCtrl,
                  label: 'اسم المستخدم',
                  icon: Icons.person_outline_rounded,
                ),
                
                // العمر
                _buildTapField(
                  label: 'العمر',
                  value: _birthDate == null ? 'غير محدد' : '$_age سنة',
                  icon: Icons.cake_outlined,
                  onTap: _pickBirthDate,
                ),
                
                // البرج
                _buildDropdownField(
                  label: 'البرج',
                  value: _zodiac,
                  icon: Icons.auto_awesome_rounded,
                  items: const ['الحمل','الثور','الجوزاء','السرطان','الأسد','العذراء','الميزان','العقرب','القوس','الجدي','الدلو','الحوت'],
                  onChanged: (v) => setState(() => _zodiac = v),
                ),
                
                // الدولة
                _buildField(
                  controller: _countryCtrl,
                  label: 'الدولة',
                  icon: Icons.public_rounded,
                ),
                
                const SizedBox(height: 40),
                
                // زر حفظ واحد فقط
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('حفظ التغييرات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
                  ),
                ),
              ],
            ),
    );
  }

  // خانة الحالة الجديدة - مثل واتساب وانستا
  Widget _buildStatusField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: TextField(
        controller: _statusCtrl,
        maxLength: 80,
        maxLines: 2,
        minLines: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, color: AppColors.text),
        decoration: const InputDecoration(
          hintText: 'اكتب حالتك...',
          hintStyle: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 14),
          border: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, color: AppColors.text),
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

  Widget _buildTapField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSub, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, color: AppColors.text)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppColors.textSub),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSub, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: Text(label, style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
                isExpanded: true,
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSub),
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, color: AppColors.text),
                items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontFamily: 'Tajawal')))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
