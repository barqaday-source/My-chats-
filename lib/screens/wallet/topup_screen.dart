import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';

class TopUpScreen extends StatelessWidget {
  const TopUpScreen({super.key});

  Future<void> _openWhatsApp(String package) async {
    // غير الرقم لرقمك
    const agentNumber = '9647700000000';
    final text = Uri.encodeComponent('مرحبا، اريد شحن $package في تطبيق الدردشة\nمعرفي: ');
    final uri = Uri.parse('https://wa.me/$agentNumber?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packages = [
      {'coins': '100', 'price': '\$1', 'label': 'باقة البداية'},
      {'coins': '500', 'price': '\$5', 'label': 'الأكثر مبيعاً', 'best': true},
      {'coins': '1000', 'price': '\$9', 'label': 'باقة المحترفين'},
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('اشحن رصيدك', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: const Text(
              'الشحن عبر الوكيل المعتمد فقط\nزين كاش / OKX / آسيا حوالة',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          ...packages.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _openWhatsApp('${p['coins']} نقطة'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.glassBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p['best'] == true ? AppColors.primary : AppColors.glassBorder, width: p['best'] == true ? 1.5 : 0.5),
                ),
                child: Row(
                  children: [
                    Text('${p['coins']} 🪙', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(p['price'] as String, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, color: AppColors.primary)),
                        Text(p['label'] as String, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_left_rounded, color: AppColors.textSub),
                  ],
                ),
              ),
            ),
          )),
          const SizedBox(height: 12),
          const Text(
            'بعد التحويل، سيتم إضافة النقاط لحسابك خلال دقائق.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSub),
          ),
        ],
      ),
    );
  }
}
