import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_snackbar.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  Future<void> _buy(BuildContext context, String id, int price, String name) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user!;
    if (user.coins < price) {
      showAppSnack(context, 'رصيدك غير كافي', success: false);
      return;
    }
    final supabase = Supabase.instance.client;
    try {
      await supabase.rpc('spend_coins', params: {'p_amount': price, 'p_note': name});
      await auth.refreshUser();
      if (context.mounted) showAppSnack(context, 'تم تفعيل $name', success: true);
    } catch (e) {
      if (context.mounted) showAppSnack(context, 'فشل: $e', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coins = context.watch<AuthProvider>().user?.coins ?? 0;
    final offers = [
      {'id': 'room_rain', 'name': 'ثيم المطر', 'price': 200, 'desc': 'خلفية متحركة + صوت مطر'},
      {'id': 'room_boost', 'name': 'ترقية الغرفة 24س', 'price': 100, 'desc': 'غرفتك أول القائمة'},
      {'id': 'profile_boost', 'name': 'ترقية الحساب أسبوع', 'price': 300, 'desc': 'تظهر أول المستخدمين'},
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('العروض المميزة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(child: Text('$coins 🪙', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, color: AppColors.primary))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: offers.map((o) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o['name'] as String, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, color: AppColors.text)),
                  const SizedBox(height: 4),
                  Text(o['desc'] as String, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub)),
                  const SizedBox(height: 8),
                  Text('${o['price']} 🪙', style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.primary, fontWeight: FontWeight.w700)),
                ],
              )),
              ElevatedButton(
                onPressed: () => _buy(context, o['id'] as String, o['price'] as int, o['name'] as String),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('شراء', style: TextStyle(fontFamily: 'Tajawal')),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}
