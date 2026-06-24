import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_colors.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_snackbar.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onRead;
  const NotificationsScreen({super.key, this.onRead});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _svc = NotificationService();
  List<NotificationModel> _currentNotifs = []; // نخزن القائمة الحالية

  // وضع التحديد
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  Future<void> _markRead() async {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;
    await _svc.markAllRead(uid);
    widget.onRead?.call();
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _svc.deleteNotification(id);
      if (mounted) showAppSnack(context, 'تم حذف الإشعار', success: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل الحذف', success: false);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await _showDeleteSheet(context, _selectedIds.length);
    if (confirm!= true) return;

    try {
      await _svc.deleteNotifications(_selectedIds.toList());
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _selectionMode = false;
      });
      showAppSnack(context, 'تم الحذف', success: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'فشل الحذف', success: false);
    }
  }

  Future<bool?> _showDeleteSheet(BuildContext context, int count) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              border: Border(top: BorderSide(color: AppColors.glassBorder, width: 0.5)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(
                    color: AppColors.divider, borderRadius: BorderRadius.circular(2),
                  )),
                  const SizedBox(height: 20),
                  const Icon(Icons.delete_rounded, size: 44, color: AppColors.danger),
                  const SizedBox(height: 12),
                  Text('حذف $count إشعار؟',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('لا يمكن التراجع عن هذا الإجراء',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppColors.textSub)),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        side: BorderSide(color: AppColors.glassBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('حذف', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                    )),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _currentNotifs.length) {
        _selectedIds.clear();
        _selectionMode = false;
      } else {
        _selectedIds.addAll(_currentNotifs.map((n) => n.id));
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  IconData _icon(String type) {
    switch (type) {
      case 'message': return Icons.chat_bubble_rounded;
      case 'report_reply': return Icons.gavel_rounded;
      case 'admin': return Icons.admin_panel_settings_rounded;
      case 'account_blocked': return Icons.block_rounded;
      case 'account_unblocked': return Icons.check_circle_rounded;
      case 'room_approved': return Icons.meeting_room_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'message': return AppColors.primary;
      case 'report_reply': return AppColors.warning;
      case 'admin': return AppColors.danger;
      case 'account_blocked': return AppColors.danger;
      case 'account_unblocked': return AppColors.success;
      case 'room_approved': return AppColors.accent;
      default: return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.id?? '';
    if (uid.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 80,
        title: const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('الإشعارات', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 20)),
        ),
        actions: [
          if (_selectionMode)...[
            TextButton(
              onPressed: _selectAll,
              child: Text(
                _selectedIds.length == _currentNotifs.length? 'إلغاء الكل' : 'تحديد الكل',
                style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _cancelSelection,
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: AppColors.danger),
              onPressed: () => setState(() => _selectionMode = true),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGrad),
        child: StreamBuilder<List<NotificationModel>>(
          stream: _svc.userNotifications(uid),
          builder: (_, snap) {
            if (snap.hasError) {
              return Center(child: Text('خطأ: ${snap.error}', style: const TextStyle(color: AppColors.textSub)));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            final notifs = snap.data!;
            _currentNotifs = notifs; // خزن القائمة عشان "تحديد الكل"

            if (notifs.isEmpty) {
              return _buildEmptyState();
            }
            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              color: AppColors.primary,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: notifs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final n = notifs[i];
                  return _buildNotifTile(n);
                },
              ),
            );
          },
        ),
      ),
      // زر حذف ثابت تحت لما يكون وضع التحديد شغال
      bottomNavigationBar: _selectionMode && _selectedIds.isNotEmpty
     ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _deleteSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.delete_rounded, size: 20),
                  label: Text('حذف ${_selectedIds.length}',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          )
        : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded, color: AppColors.primary, size: 48),
          ),
          const SizedBox(height: 16),
          const Text('لا توجد إشعارات', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('ستظهر إشعاراتك هنا', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNotifTile(NotificationModel n) {
    final isSelected = _selectedIds.contains(n.id);
    final c = _color(n.type);

    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _deleteNotification(n.id);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: InkWell(
        onTap: () {
          if (_selectionMode) {
            _toggleSelection(n.id);
          } else {
            _svc.markRead(n.id);
          }
        },
        onLongPress: () {
          if (!_selectionMode) {
            setState(() {
              _selectionMode = true;
              _selectedIds.add(n.id);
            });
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected? AppColors.primary.withOpacity(0.1) : Colors.transparent,
            border: const Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox لو وضع التحديد شغال
              if (_selectionMode)...[
                Icon(
                  isSelected? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected? AppColors.primary : AppColors.textSub,
                  size: 22,
                ),
                const SizedBox(width: 12),
              ] else...[
                // أيقونة النوع
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon(n.type), color: c, size: 20),
                ),
                const SizedBox(width: 12),
              ],
              // النص + الوقت
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: n.isRead? FontWeight.w500 : FontWeight.w700,
                        color: AppColors.text,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          timeago.format(n.createdAt, locale: 'ar'),
                          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub, fontSize: 11),
                        ),
                        if (!n.isRead &&!_selectionMode)...[
                          const SizedBox(width: 8),
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
