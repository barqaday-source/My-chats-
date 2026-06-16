import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/message_model.dart';
import '../../models/room_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/chat/voice_recorder_button.dart';
import '../chat/message_bubble.dart';

class RoomChatScreen extends StatefulWidget {
  final RoomModel room;
  const RoomChatScreen({super.key, required this.room});
  @override
  State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen> {
  final _chat = ChatService();
  final _storage = StorageService();
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final _supabase = Supabase.instance.client;
  bool _sending = false;
  bool _shouldScroll = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    final user = context.read<AuthProvider>().user!;
    final message = MessageModel(
      id: const Uuid().v4(),
      senderId: user.id,
      receiverId: '', // غرفة مو شخص
      senderName: user.username,
      senderAvatar: user.avatarUrl,
      chatId: widget.room.id,
      content: text,
      createdAt: DateTime.now(),
      type: MsgType.text,
    );

    _msgCtrl.clear();
    setState(() => _sending = true);

    try {
      await _chat.sendRoomMessage(message);
      _shouldScroll = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل الإرسال',
                style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    if (_sending) return;
    final img =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (img == null) return;

    setState(() => _sending = true);
    try {
      final user = context.read<AuthProvider>().user!;
      final url = await _storage.uploadChatMedia(widget.room.id, File(img.path), 'image');
      if (url!= null) {
        await _chat.sendRoomMessage(MessageModel(
          id: const Uuid().v4(),
          senderId: user.id,
          receiverId: '', // غرفة مو شخص
          senderName: user.username,
          senderAvatar: user.avatarUrl,
          chatId: widget.room.id,
          content: '📷 صورة',
          type: MsgType.image,
          mediaUrl: url,
          createdAt: DateTime.now(),
        ));
        _shouldScroll = true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل رفع الصورة',
                style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAudio(String localPath, int duration) async {
    setState(() => _sending = true);
    try {
      final user = context.read<AuthProvider>().user!;
      final file = File(localPath);
      final fileName = '${const Uuid().v4()}.m4a';
      
      await _supabase.storage.from('chat-audio').upload(fileName, file);
      final url = _supabase.storage.from('chat-audio').getPublicUrl(fileName);

      await _chat.sendRoomMessage(MessageModel(
        id: const Uuid().v4(),
        senderId: user.id,
        receiverId: '', // غرفة مو شخص
        senderName: user.username,
        senderAvatar: user.avatarUrl,
        chatId: widget.room.id,
        content: '🎤 رسالة صوتية',
        type: MsgType.audio,
        audioUrl: url,
        duration: duration,
        createdAt: DateTime.now(),
      ));
      _shouldScroll = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل إرسال الرسالة الصوتية',
                style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollDown() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _roomActions(BuildContext ctx) {
    final user = context.read<AuthProvider>().user!;
    final isOwner = widget.room.ownerId == user.id;
    
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.bgCard,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.textSub,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.people_outline_rounded,
                color: AppColors.primary),
            title: const Text('الأعضاء',
                style: TextStyle(fontFamily: 'Tajawal', color: AppColors.text)),
            onTap: () {
              Navigator.pop(ctx);
            },
          ),
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('حذف الغرفة',
                  style: TextStyle(fontFamily: 'Tajawal', color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.bgCard2,
                    title: const Text('حذف الغرفة؟',
                        style: TextStyle(fontFamily: 'Tajawal', color: AppColors.white)),
                    content: const Text('لا يمكن التراجع عن هذا الإجراء',
                        style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('إلغاء')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('حذف'),
                      )
                    ],
                  ),
                );
                if (confirm == true) {
                  await _supabase.from('rooms').delete().eq('id', widget.room.id);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
        ]),
      ),
    );
  }

  Widget _buildInputRow() {
    final hasText = _msgCtrl.text.trim().isNotEmpty;
    return Row(children: [
      IconButton(
        icon: const Icon(Icons.image_outlined, color: AppColors.textSub),
        onPressed: _sending? null : _pickImage,
      ),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard2,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder, width: 0.8),
          ),
          child: TextField(
            controller: _msgCtrl,
            enabled:!_sending,
            style: const TextStyle(
                fontFamily: 'Tajawal', color: AppColors.text, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'اكتب رسالة...',
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _sendText(),
          ),
        ),
      ),
      const SizedBox(width: 6),
      _sending
        ? const SizedBox(
              width: 40,
              height: 40,
              child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary)))
          : hasText
            ? GestureDetector(
                  onTap: _sendText,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 10)
                      ],
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: AppColors.white, size: 20),
                  ),
                )
              : VoiceRecorderButton(
                  onRecordComplete: (path, duration) => _sendAudio(path, duration),
                ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGrad),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                decoration: BoxDecoration(color: AppColors.bgCard.withOpacity(0.7)),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CircleAvatar(
                    radius: 19,
                    backgroundImage: widget.room.imageUrl!= null
                      ? NetworkImage(widget.room.imageUrl!)
                        : null,
                    backgroundColor: AppColors.primary,
                    child: widget.room.imageUrl == null
                      ? const Icon(Icons.group_rounded, color: AppColors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(widget.room.name,
                            style: const TextStyle(
                                fontFamily: 'Tajawal',
                                color: AppColors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        const Text(
                          'اضغط للخيارات',
                          style: TextStyle(
                              fontFamily: 'Tajawal',
                              color: AppColors.textSub,
                              fontSize: 11),
                        ),
                      ])),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppColors.textSub),
                    onPressed: () => _roomActions(context),
                  ),
                ]),
              ),
              
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _chat.roomMessages(widget.room.id),
                  builder: (_, snap) {
                    if (snap.hasError) {
                      return Center(
                          child: Text('خطأ في تحميل الرسائل',
                              style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: AppColors.danger)));
                    }
                    if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary));
                    }
                    final msgs = snap.data?? [];
                    
                    if (_shouldScroll) {
                      _shouldScroll = false;
                      WidgetsBinding.instance
                        .addPostFrameCallback((_) => _scrollDown());
                    }

                    return ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        return MessageBubble(
                          message: msgs[i],
                          isMe: msgs[i].senderId == user.id,
                        );
                      },
                    );
                  },
                ),
              ),
              
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: AppColors.bgCard.withOpacity(0.95),
                  border: const Border(
                      top: BorderSide(color: AppColors.glassBorder, width: 0.5)),
                ),
                child: _buildInputRow(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
