import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

class EditContactScreen extends StatefulWidget {
  const EditContactScreen({super.key});
  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  final _supabase = Supabase.instance.client;
  final _whatsCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _whatsCtrl.dispose();
    _emailCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _supabase.from('app_contact').select().eq('id', 1).single();
      _whatsCtrl.text = data['whatsapp_number'] ?? '';
      _emailCtrl.text = data['contact_email'] ?? '';
      _msgCtrl.text = data['support_message'] ?? '';
    } catch (e) {
      debugPrint('Load contact error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _supabase.from('app_contact').update({
        'whatsapp_number': _whatsCtrl.text.trim(),
        'contact_email': _emailCtrl.text.trim(),
        'support_message': _msgCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', 1);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الحفظ', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحفظ: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل معلومات التواصل', style: TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: AppColors.bgCard,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGrad),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _whatsCtrl,
                    style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text),
                    decoration: InputDecoration(
                      labelText: 'رقم واتساب بدون +',
                      hintText: '9647701234567',
                      labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailCtrl,
                    style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text),
                    decoration: InputDecoration(
                      labelText: 'ايميل الدعم',
                      labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text),
                    decoration: InputDecoration(
                      labelText: 'رسالة واتساب الافتراضية',
                      labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _saving ? 'جار الحفظ...' : 'حفظ',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
