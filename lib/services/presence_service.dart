import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;
  static final PresenceService _i = PresenceService._();
  factory PresenceService() => _i;
  PresenceService._();

  void init() {
    WidgetsBinding.instance.addObserver(this);
    _set(true);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _set(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _set(true);
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.detached) _set(false);
  }

  Future<void> _set(bool online) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase.from('users').update({
      'is_online': online,
      'last_seen': DateTime.now().toIso8601String()
    }).eq('id', uid);
  }
}
