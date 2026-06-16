import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_colors.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/voice_recorder_button.dart';

class PrivateChatScreen extends StatefulWidget {
  final UserModel other;

  const PrivateChatScreen({
    super.key,
    required this.other,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _supabase = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<MessageModel> _messages = [];
  late final String _chatId;
  RealtimeChannel? _channel;
  MessageModel? _replyTo;

  @override
  void initState() {
    super.initState();
    final currentUser = context.read<AuthProvider>().user!;
    _chatId = MessageModel.generateChatId(currentUser.id, widget.other.id);
    _loadMessages();
    _subscribeToMessages();
    _msgCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final data = await _supabase
      .from('messages')
      .select()
      .eq('chat_id', _chatId)
      .order('created_at', ascending: true);

    setState(() {
      _messages.clear();
      _messages.addAll(data.map((e) => MessageModel.fromJson(e)));
    });
    _scrollToBottom();
    _markAsRead();
  }

  void _subscribeToMessages() {
    _channel = _supabase
      .channel('messages:$_chatId')
      .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: _chatId,
          ),
          callback: (payload) {
            final msg = MessageModel.fromJson(payload.newRecord);
            if (!_messages.any((m) => m.id == msg.id)) {
              setState(() => _messages.add(msg));
              _scrollToBottom();
              _markAsRead();
            }
          },
        )
      .subscribe();
  }

  Future<void> _markAsRead() async {
    final currentUser = context.read<AuthProvider>().user!;
    await _supabase
      .from('messages')
      .update({'is_read': true})
      .eq('chat_id', _chatId)
      .eq('receiver_id', currentUser.id)
      .eq('is_read', false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final user = context.read<AuthProvider>().user!;
    final message = MessageModel(
      id: const Uuid().v4(),
      chatId: _chatId,
      senderId: user.id,
      receiverId: widget.other.id,
      content: text,
      type: MsgType.text,
      senderName: user.username,
      senderAvatar: user.avatarUrl,
      createdAt: DateTime.now(),
    );

    _msgCtrl.clear();
    setState(() => _replyTo = null);
    
    await _supabase.from('messages').insert(message.toJson());
  }

  Future<void> _sendImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    
    final file = File(result.files.first.path!);
    final user = context.read<AuthProvider>().user!;
    final fileName = '${const Uuid().v4()}${p.extension(file.path)}';
    
    await _supabase.storage.from('chat-images').upload(fileName, file);
    final mediaUrl = _supabase.storage.from('chat-images').getPublicUrl(fileName);

    final message = MessageModel(
      id: const Uuid().v4(),
      chatId: _chatId,
      senderId: user.id,
      receiverId: widget.other.id,
      content: 'صورة',
      type: MsgType.image,
      mediaUrl: mediaUrl,
      senderName: user.username,
      senderAvatar: user.avatarUrl,
      createdAt: DateTime.now(),
    );

    await _supabase.from('messages').insert(message.toJson());
  }

  Future<void> _sendAudio(String path, int duration) async {
    final user = context.read<AuthProvider>().user!;
    final fileName = '${const Uuid().v4()}.m4a';
    
    await _supabase.storage.from('chat-audio').upload(fileName, File(path));
    final audioUrl = _supabase.storage.from('chat-audio').getPublicUrl(fileName);

    final message = MessageModel(
      id: const Uuid().v4(),
      chatId: _chatId,
      senderId: user.id,
      receiverId: widget.other.id,
      content: '🎤 رسالة صوتية',
      type: MsgType.audio,
      audioUrl: audioUrl,
      duration: duration,
      senderName: user.username,
      senderAvatar: user.avatarUrl,
      createdAt: DateTime.now(),
    );

    await _supabase.from('messages').insert(message.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user!;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.other.avatarUrl!= null
               ? NetworkImage(widget.other.avatarUrl!)
                  : null,
              child: widget.other.avatarUrl == null
               ? Text(widget.other.username[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.other.username,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                Text(
                  widget.other.isOnline? 'متصل الآن' : 'غير متصل',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                final isMe = msg.senderId == currentUser.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
                    child: MessageBubble(
                      message: msg,
                      isMe: isMe,
                    ),
                  ),
                );
              },
            ),
          ),
          if (_replyTo!= null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              color: AppColors.bgCard,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الرد على ${_replyTo!.senderName?? "مستخدم"}',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _replyTo!.type == MsgType.text
                           ? _replyTo!.content
                              : _replyTo!.type == MsgType.image
                               ? 'صورة'
                                  : 'رسالة صوتية',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _replyTo = null),
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            color: AppColors.bgCard,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    onPressed: _sendImage,
                    icon: const Icon(Icons.attach_file_rounded, color: AppColors.textMuted),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.white),
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة...',
                        hintStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _msgCtrl.text.trim().isNotEmpty
                   ? IconButton(
                          onPressed: _sendText,
                          icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                        )
                      : VoiceRecorderButton(
                          onRecordComplete: (path, duration) => _sendAudio(path, duration),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
