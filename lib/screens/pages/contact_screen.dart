import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});
  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _supabase = Supabase.instance.client;
  String? whatsapp;
  String? email;
  String? msg;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    try {
      final data = await _supabase
          .from('app_contact')
          .select()
          .eq('id', 1)
          .single();
      setState(() {
        whatsapp = data['whatsapp_number'];
        email = data['contact_email'];
        msg = data['support_message'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      debugPrint('contact load error: $e');
    }
  }

  Future<void> _openWhatsApp() async {
    if (whatsapp == null) return;
    final text = Uri.encodeComponent(msg ?? 'مرحبا');
    final uri = Uri.parse('https://wa.me/$whatsapp?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError('تأكد من تثبيت واتساب');
    }
  }

  Future<void> _openEmail() async {
    if (email == null) return;
    final subject = Uri.encodeComponent('دعم تطبيق CChat');
    final body = Uri.encodeComponent(msg ?? 'مرحبا');
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showError('لا يوجد تطبيق بريد');
    }
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: const TextStyle(fontFamily: 'Tajawal'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تواصل معنا', style: TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: AppColors.bgCard,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGrad),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 20),
                  if (whatsapp != null)
                    _ContactTile(
                      icon: Icons.chat_rounded,
                      title: 'واتساب',
                      subtitle: '+$whatsapp',
                      color: Colors.green,
                      onTap: _openWhatsApp,
                    ),
                  const SizedBox(height: 12),
                  if (email != null)
                    _ContactTile(
                      icon: Icons.email_rounded,
                      title: 'البريد الإلكتروني',
                      subtitle: email!,
                      color: Colors.blue,
                      onTap: _openEmail,
                    ),
                  if (whatsapp == null && email == null)
                    const Center(
                      child: Text(
                        'لا توجد وسائل تواصل متاحة حالياً',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.textSub,
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.textSub,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            color: AppColors.textSub, size: 18),
        onTap: onTap,
      ),
    );
  }
}
