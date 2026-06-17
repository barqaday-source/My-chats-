import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
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
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  List<Map<String, dynamic>> _messages = [];
  bool _isRecording = false;
  bool _isUploading = false;
  String? _recordingPath;
  Timer? _recordTimer;
  int _recordDuration = 0;
  String? _currentlyPlayingId;

  String get _currentUserId => _supabase.auth.currentUser!.id;
  String get _chatId {
    final ids = [_currentUserId, widget.peerId]..sort();
    return ids.join('_');
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
    _messageController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
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
    _supabase
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

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        await Permission.microphone.request();
      }

      final dir = await getTemporaryDirectory();
      _recordingPath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _recordingPath!,
      );

      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordDuration++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التسجيل: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();

      setState(() => _isRecording = false);

      if (path!= null && _recordDuration > 0) {
        await _uploadAudio(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إيقاف التسجيل: $e')),
        );
      }
    }
  }

  Future<void> _uploadAudio(String path) async {
    setState(() => _isUploading = true);
    try {
      final file = File(path);
      final fileBytes = await file.readAsBytes();
      final fileName = '${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
        'duration': _recordDuration,
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
      final image = await picker.pickImage(source: ImageSource.gallery);
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

  Future<void> _playAudio(String url, String messageId) async {
    try {
      if (_currentlyPlayingId == messageId) {
        await _audioPlayer.stop();
        setState(() => _currentlyPlayingId = null);
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(url));
        setState(() => _currentlyPlayingId = messageId);

        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _currentlyPlayingId = null);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التشغيل: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
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
              Text(
                widget.peerName,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender_id'] == _currentUserId;
                return _MessageBubble(
                  message: msg,
                  isMe: isMe,
                  isPlaying: _currentlyPlayingId == msg['id'],
                  onPlayAudio: () => _playAudio(msg['audio_url'], msg['id']),
                );
              },
            ),
          ),
          if (_isUploading)
            const LinearProgressIndicator(color: AppColors.primary),
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
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 0.5)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _isUploading? null : _pickImage,
              icon: const Icon(Icons.image_rounded, color: AppColors.textSecondary),
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
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: hasText? _sendMessage : null,
              onLongPressStart: hasText? null : (_) => _startRecording(),
              onLongPressEnd: hasText? null : (_) => _stopRecording(),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isRecording
            ? [Colors.red, Colors.red.shade700]
                        : [AppColors.primary, AppColors.primaryDark],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasText? Icons.send_rounded : Icons.mic_rounded,
                  color: AppColors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isPlaying;
  final VoidCallback onPlayAudio;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isPlaying,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: isMe
            ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark])
              : null,
          color: isMe? null : AppColors.bgCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe? 16 : 4),
            bottomRight: Radius.circular(isMe? 4 : 16),
          ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final type = message['type']?? 'text';

    if (type == 'image' && message['media_url']!= null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: message['media_url'],
          placeholder: (context, url) => Container(
            width: 200,
            height: 200,
            color: AppColors.bgCard2,
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.error),
          width: 200,
          fit: BoxFit.cover,
        ),
      );
    }

    if (type == 'voice' && message['audio_url']!= null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onPlayAudio,
            icon: Icon(
              isPlaying? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: AppColors.white,
            ),
          ),
          Text(
            '${message['duration']?? 0}s',
            style: const TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.white,
            ),
          ),
        ],
      );
    }

    return Text(
      message['content']?? '',
      style: const TextStyle(
        fontFamily: 'Tajawal',
        color: AppColors.white,
        fontSize: 15,
      ),
    );
  }
}
