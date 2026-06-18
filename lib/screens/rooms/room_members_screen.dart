import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/room_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/room_service.dart';
import '../../widgets/user_avatar.dart';
import '../profile/user_profile_screen.dart';

class RoomMembersScreen extends StatefulWidget {
  final RoomModel room;
  const RoomMembersScreen({super.key, required this.room});

  @override
  State<RoomMembersScreen> createState() => _RoomMembersScreenState();
}

class _RoomMembersScreenState extends State<RoomMembersScreen> {
  final _roomService = RoomService();
  final _supabase = Supabase.instance.client;
  List<UserModel> _members = [];
  bool _loading = true;
  late bool _isOwner;

  @override
  void initState() {
    super.initState();
    final me = context.read<AuthProvider>().user!;
    _isOwner = me.id == widget.room.ownerId;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    try {
      final membersData = await _roomService.getRoomMembers(widget.room.id);
      if (mounted) {
        setState(() {
          _members = membersData.map((m) => UserModel.fromJson(m)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Load members error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _kickMember(String userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text(
          'طرد عضو',
          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
        ),
        content: Text(
          'هل تريد طرد $username من الغرفة؟',
          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'طرد',
              style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase
          .from('room_members')
          .delete()
          .eq('room_id', widget.room.id)
          .eq('user_id', userId);
      _loadMembers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthProvider>().user!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title: Text(
          'أعضاء ${widget.room.name}',
          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadMembers,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGrad),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadMembers,
                child: ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final isOwner = member.id == widget.room.ownerId;
                    final isMe = member.id == me.id;

                    return ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(userId: member.id),
                          ),
                        );
                      },
                      leading: UserAvatar(
                        url: member.avatarUrl,
                        name: member.username,
                        isOnline: member.isOnline,
                        size: 48,
                      ),
                      title: Row(
                        children: [
                          Text(
                            member.username,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          if (isOwner) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'المالك',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.online.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'أنت',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: AppColors.online,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: member.isOnline
                          ? const Text(
                              'متصل الآن',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                color: AppColors.online,
                                fontSize: 12,
                              ),
                            )
                          : Text(
                              member.lastSeen != null
                                  ? 'آخر ظهور ${_formatLastSeen(member.lastSeen!)}'
                                  : 'غير متصل',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                color: AppColors.textSub,
                                fontSize: 12,
                              ),
                            ),
                      trailing: _isOwner && !isOwner && !isMe
                          ? IconButton(
                              icon: const Icon(Icons.person_remove_rounded),
                              color: AppColors.danger,
                              onPressed: () => _kickMember(member.id, member.username),
                            )
                          : null,
                    );
                  },
                ),
              ),
      ),
    );
  }

  String _formatLastSeen(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'قبل ${diff.inDays} يوم';
    return '${date.day}/${date.month}/${date.year}';
  }
}
