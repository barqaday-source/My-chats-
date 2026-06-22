import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService with WidgetsBindingObserver {
  final _db = Supabase.instance.client;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
    // heartbeat كل 30 ثانية
    Stream.periodic(const Duration(seconds: 30)).listen((_) => _setOnline(true));
  }

  Future<void> _setOnline(bool online) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db.from('profiles').update({
      'is_online': online,
      'last_seen': DateTime.now().toIso8601String(),
    }).eq('id', uid);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _setOnline(true);
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _setOnline(false);
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnline(false);
  }
}
