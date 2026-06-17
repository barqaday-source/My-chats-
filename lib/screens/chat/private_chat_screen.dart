import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_colors.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/voice_recorder_button.dart';
import '../profile/user_profile_screen.dart';

class PrivateChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String? peerAvatar;

  const PrivateChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isUploading = false;
  StreamSubscription? _messageSubscription;

  String get _currentUserId => _supabase.auth.currentUser!.id;
  String get _chatId {
    final ids = [_currentUserId, widget.peerId]..sort();
    return ids.join('_');
  }

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    _loadMessages();
    _subscribeToMessages();
    _messageController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final response = await _supabase
         .from('private_messages')
         .select()
         .eq('chat_id', _chatId)
         .order('created_at', ascending: true);

      setState(() => _messages = List<Map<String, dynamic>>.from(response));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الرسائل: $e')),
        );
      }
    }
  }

  void _subscribeToMessages() {
    _messageSubscription = _supabase
       .channel('public:private_messages:chat_id=eq.$_chatId')
       .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'private_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: _chatId,
          ),
          callback: (payload) {
            setState(() => _messages.add(payload.newRecord));
            _scrollToBottom();
          },
        )
       .subscribe();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    final currentUser = _supabase.auth.currentUser!;

    try {
      await _supabase.from('private_messages').insert({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'chat_id': _chatId,
        'sender_id': currentUser.id,
        'receiver_id': widget.peerId,
        'sender_name': currentUser.userMetadata?['username']?? 'مجهول',
        'sender_avatar': currentUser.userMetadata?['avatar_url'],
        'content': text,
        'type': 'text',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإرسال: $e')),
        );
      }
    }
  }

  Future<void> _uploadAudio(String path, int duration) async {
    setState(() => _isUploading = true);
    try {
      final file = File(path);
      final fileBytes = await file.readAsBytes();
      final fileName = '${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _supabase.storage.from('voice_messages').uploadBinary(fileName, fileBytes);
      final audioUrl = _supabase.storage.from('voice_messages').getPublicUrl(fileName);

      final currentUser = _supabase.auth.currentUser!;
      await _supabase.from('private_messages').insert({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'chat_id': _chatId,
        'sender_id': currentUser.id,
        'receiver_id': widget.peerId,
        'sender_name': currentUser.userMetadata?['username']?? 'مجهول',
        'sender_avatar': currentUser.userMetadata?['avatar_url'],
        'type': 'voice',
        'audio_url': audioUrl,
        'duration': duration,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل رفع الصوت: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploading = true);
      final file = File(image.path);
      final fileBytes = await file.readAsBytes();
      final fileName = '${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage.from('chat_images').uploadBinary(fileName, fileBytes);
      final imageUrl = _supabase.storage.from('chat_images').getPublicUrl(fileName);

      final currentUser = _supabase.auth.currentUser!;
      await _supabase.from('private_messages').insert({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'chat_id': _chatId,
        'sender_id': currentUser.id,
        'receiver_id': widget.peerId,
        'sender_name': currentUser.userMetadata?['username']?? 'مجهول',
        'sender_avatar': currentUser.userMetadata?['avatar_url'],
        'type': 'image',
        'media_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل رفع الصورة: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: widget.peerId),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.bgCard2,
                backgroundImage: widget.peerAvatar!= null
                   ? CachedNetworkImageProvider(widget.peerAvatar!)
                    : null,
                child: widget.peerAvatar == null
                   ? Text(
                        widget.peerName[0].toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.peerName,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
               ? Center(
                    child: Text(
                      'ابدأ المحادثة',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['sender_id'] == _currentUserId;
                      return MessageBubble(
                        message: msg,
                        isMe: isMe,
                      );
                    },
                  ),
          ),
          if (_isUploading)
            const LinearProgressIndicator(
              color: AppColors.primary,
              minHeight: 2,
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final hasText = _messageController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(
          top: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _isUploading? null : _pickImage,
              icon: const Icon(Icons.image_rounded, color: AppColors.textSecondary),
              tooltip: 'إرسال صورة',
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgCard2,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'اكتب رسالة...',
                    hintStyle: TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                ),
              ),
            ),
            const SizedBox(width: 8),
            hasText
               ? GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ),
                  )
                : VoiceRecorderButton(
                    onRecordComplete: _uploadAudio,
                  ),
          ],
        ),
      ),
    );
  }
}
