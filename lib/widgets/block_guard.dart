import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_config.dart';
import '../screens/auth/blocked_screen.dart';

class BlockGuard extends StatelessWidget {
  final Widget child;
  const BlockGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return child;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
         .from(SupabaseConfig.tUsers)
         .stream(primaryKey: ['id'])
         .eq('id', uid),
      builder: (context, snap) {
        final data = snap.data;
        final isBlocked = data!= null && data.isNotEmpty && data.first['is_blocked'] == true;
        if (isBlocked) {
          return const BlockedScreen();
        }
        return child;
      },
    );
  }
}
