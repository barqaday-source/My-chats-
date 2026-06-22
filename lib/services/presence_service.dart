import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;
  static final PresenceService _i = PresenceService._();
  factory PresenceService() => _i;
  PresenceService._();

  Timer? _heartbeat;
  bool _started = false;

  void init() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _set(true);
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) => _set(true));
  }

  // alias حتى لو ناديت start() يشتغل
  void start() => init();

  void close() {
    _heartbeat?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _set(false);
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _set(true);
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _set(false);
    }
  }

  Future<void> _set(bool online) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await supabase.from('users').update({
        'is_online': online,
        'last_seen': DateTime.now().toIso8601String()
      }).eq('id', uid);
    } catch (_) {}
  }
}
