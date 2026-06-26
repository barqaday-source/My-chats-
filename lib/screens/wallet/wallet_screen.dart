import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'topup_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final coins = user?.coins ?? 0;
    final supabase = Supabase.instance.client;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('محفظتي', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // كرت الرصيد
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text('رصيدك الحالي', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text('$coins 🪙', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpScreen())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('اشحن رصيدك', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('آخر الحركات', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.text)),
          const SizedBox(height: 12),
          FutureBuilder(
            future: supabase.from('coin_transactions')
              .select()
              .eq('user_id', supabase.auth.currentUser!.id)
              .order('created_at', ascending: false)
              .limit(20),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              final rows = snap.data as List;
              if (rows.isEmpty) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('لا توجد حركات بعد', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
                ));
              }
              return Column(
                children: rows.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.glassBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      Icon((r['amount'] as int) > 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        color: (r['amount'] as int) > 0 ? AppColors.success : AppColors.danger),
                      const SizedBox(width: 12),
                      Expanded(child: Text(r['note'] ?? r['type'], style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text))),
                      Text('${r['amount'] > 0 ? '+' : ''}${r['amount']}', 
                        style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, 
                        color: (r['amount'] as int) > 0 ? AppColors.success : AppColors.danger)),
                    ],
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
