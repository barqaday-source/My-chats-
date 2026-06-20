import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGrad),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_rounded, size: 80, color: AppColors.danger),
                const SizedBox(height: 16),
                const Text('تم حظر حسابك',
                    style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('تم حظر حسابك نهائيا من قبل الإدارة.\nللاستفسار تواصل مع الدعم.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 14)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('تسجيل خروج',
                      style: TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.w600)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
