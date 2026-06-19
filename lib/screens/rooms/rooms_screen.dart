import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/room_model.dart';
import '../../providers/auth_provider.dart';
import 'room_chat_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  List<RoomModel> _rooms = [];
  List<RoomModel> _filteredRooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() => _loading = true);
    try {
      // جيب الغرف العامة – عدل الـ query حسب جدولك إذا عندك RoomService
      final data = await supabase
          .from('rooms')
          .select()
          .order('created_at', ascending: false);

      final rooms = (data as List)
          .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _rooms = rooms;
          _filteredRooms = rooms;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل الغرف: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _filterRooms(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredRooms = _rooms;
      } else {
        _filteredRooms = _rooms
            .where((r) => r.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _openRoom(RoomModel room) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomChatScreen(room: room)),
    ).then((_) => _loadRooms());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGrad),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'الغرف',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            // بحث بإطار واحد
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _searchController,
                onChanged: _filterRooms,
                textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'ابحث عن غرفة...',
                  hintStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.navy),
                  filled: true,
                  fillColor: AppColors.bgCard2,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filteredRooms.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.forum_outlined, size: 56, color: AppColors.navy),
                              SizedBox(height: 12),
                              Text(
                                'لا توجد غرف',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: AppColors.textSub,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadRooms,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 20),
                            itemCount: _filteredRooms.length,
                            itemBuilder: (context, index) {
                              final room = _filteredRooms[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.bgCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.glassBorder, width: 0.8),
                                ),
                                child: ListTile(
                                  onTap: () => _openRoom(room),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.bgCard2,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.forum_rounded, color: AppColors.navy),
                                  ),
                                  title: Text(
                                    room.name,
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      color: AppColors.text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      room.description ?? 'غرفة عامة',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        color: AppColors.textSub,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.circle, size: 8, color: AppColors.success),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${room.onlineCount}',
                                              style: const TextStyle(
                                                fontFamily: 'Tajawal',
                                                color: AppColors.navy,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppColors.textSub),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
