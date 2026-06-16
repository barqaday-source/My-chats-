import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool isLogin;
  const LoginScreen({super.key, this.isLogin = true});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late bool _isLogin;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) return;
    if (!_isLogin && _nameCtrl.text.trim().isEmpty) return;

    final auth = context.read<AuthProvider>();
    bool ok;
    
    if (_isLogin) {
      ok = await auth.login(email, pass);
    } else {
      ok = await auth.register(email, pass, _nameCtrl.text.trim());
    }
    
    if (ok && mounted) {
      // 1️⃣ إظهار إشعار النجاح فوراً لكي تراه بعينك في أسفل الشاشة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isLogin ? 'تم تسجيل الدخول بنجاح! جاري تحميل بياناتك...' : 'تم إنشاء الحساب بنجاح!',
            style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white),
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );

      // 2️⃣ حجر الزاوية: تأخير برمي لمدة 800 ملي ثانية لإعطاء الـ AuthProvider الوقت الكافي 
      // لجلب سطر الـ Profile الخاص بك وتحديث رتبتك (Admin/Mod) بالكامل من Supabase
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        // 3️⃣ الانتقال الآمن الآن وأنت بكامل صلاحيات حسابك وليس كزائر
        Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const HomeScreen()), 
            (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGrad),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 16),
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              const SizedBox(height: 20),
              Text(
                _isLogin ? AppStrings.login : AppStrings.register,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin ? 'مرحباً بعودتك إلى سي شات' : 'انضم إلى مجتمع سي شات',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 36),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.glass,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.glassBorder, width: 0.8),
                    ),
                    child: Column(children: [
                      if (!_isLogin) ...[
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم المستخدم',
                            prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textSub),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: AppStrings.email,
                          prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSub),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: AppStrings.password,
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textSub),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textSub),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      if (auth.error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(auth.error!,
                                style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.danger, fontSize: 12))),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: auth.loading ? null : _submit,
                          child: auth.loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                            : Text(_isLogin ? AppStrings.login : AppStrings.register),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  auth.clearError();
                  setState(() => _isLogin = !_isLogin);
                },
                child: Text(
                  _isLogin ? 'ليس لديك حساب؟ سجّل الآن' : 'لديك حساب؟ سجّل دخولك',
                  style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.primaryLight, fontSize: 14),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
