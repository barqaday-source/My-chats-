import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _zodiacCtrl = TextEditingController();
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _usernameCtrl,
            decoration: const InputDecoration(labelText: 'اسم المستخدم'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'النبذة'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _whatsappCtrl,
            decoration: const InputDecoration(labelText: 'واتساب'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _birthDateCtrl,
            decoration: const InputDecoration(labelText: 'تاريخ الميلاد'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _zodiacCtrl,
            decoration: const InputDecoration(labelText: 'البرج'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final success = await context.read<AuthProvider>().updateProfile({
                'username': _usernameCtrl.text.trim(),
                'bio': _bioCtrl.text.trim(),
                'whatsapp': _whatsappCtrl.text.trim(),
                'birth_date': _birthDateCtrl.text.trim().isEmpty? null : _birthDateCtrl.text.trim(),
                'zodiac': _zodiacCtrl.text.trim(),
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success? 'تم التحديث بنجاح' : 'فشل التحديث'),
                    backgroundColor: success? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
