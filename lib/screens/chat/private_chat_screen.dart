import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../models/message_model.dart';

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
  final _chatSvc = ChatService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _recorder = FlutterSoundRecorder();
  final _player = AudioPlayer();
  final _picker = ImagePicker();
  final _supabase = Supabase.instance.client;

  bool _isRecording = false;
  String? _recordingPath;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _recorder.closeRecorder();
    _player.dispose();
    super.dispose();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
  }

  Future<void> _startRecording() async {
    try {
      await _recorder.startRecorder(toFile: 'audio.aac');
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });
      _startTimer();
    } catch (e) {
      debugPrint('Start recording error: $e');
    }
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_isRecording) return false;
      setState(() => _recordDuration++);
      return true;
    });
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });
      if (path!= null) _sendAudio(path);
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }
  }

  Future<void> _sendAudio(String path) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';
      final fileBytes = await File(path).readAsBytes();
      await _supabase.storage.from('voice_messages').uploadBinary(fileName, fileBytes);
      final audioUrl = _supabase.storage.from('voice_messages').getPublicUrl(fileName);

      final message = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: MessageModel.generateChatId(user.id, widget.peerId),
        senderId: user.id,
        receiverId: widget.peerId,
        senderName: auth.userProfile?['username']?? user.email?.split('@')[0]?? 'مجهول',
        senderAvatar: auth.userProfile?['avatar_url'],
        content: 'رسالة صوتية',
        type: MsgType.audio,
        audioUrl: audioUrl,
        duration: _recordDuration,
        createdAt: DateTime.now(),
      );

      await _chatSvc.sendPrivateMessage(widget.peerId, message);
      _scrollToBottom();
    } catch (e) {
      debugPrint('Send audio error: $e');
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final auth = context.read<AuthProvider>();
      final user = auth.user;
      if (user == null) return;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileBytes = await picked.readAsBytes();
      await _supabase.storage.from('chat_images').uploadBinary(fileName, fileBytes);
      final imageUrl = _supabase.storage.from('chat_images').getPublicUrl(fileName);

      final message = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: MessageModel.generateChatId(user.id, widget.peerId),
        senderId: user.id,
        receiverId: widget.peerId,
        senderName: auth.userProfile?['username']?? user.email?.split('@')[0]?? 'مجهول',
        senderAvatar: auth.userProfile?['avatar_url'],
        content: '📷 صورة',
        type: MsgType.image,
        mediaUrl: imageUrl,
        createdAt: DateTime.now(),
      );

      await _chatSvc.sendPrivateMessage(widget.peerId, message);
      _scrollToBottom();
    } catch (e) {
      debugPrint('Send image error: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    _msgCtrl.clear();

    final message = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: MessageModel.generateChatId(user.id, widget.peerId),
      senderId: user.id,
      receiverId: widget.peerId,
      senderName: auth.userProfile?['username']?? user.email?.split('@')[0]?? 'مجهول',
      senderAvatar: auth.userProfile?['avatar_url'],
      content: text,
      createdAt: DateTime.now(),
    );

    await _chatSvc.sendPrivateMessage(widget.peerId, message);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user!.id;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.peerAvatar!= null
           ? NetworkImage(widget.peerAvatar!)
                  : null,
              child: widget.peerAvatar == null
           ? Text(widget.peerName[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 12),
            Text(widget.peerName, style: const TextStyle(fontFamily: 'Tajawal')),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGrad),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _chatSvc.getPrivateMessages(widget.peerId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data!;
                  return ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      final isMe = msg.senderId == currentUserId;
                      return _MessageBubble(msg: msg, isMe: isMe, player: _player);
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(8, 8 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _pickAndSendImage,
                      icon: const Icon(Icons.image_rounded, color: AppColors.primary),
                    ),
                    Expanded(
                      child: _isRecording
                     ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.mic, color: AppColors.danger, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'جاري التسجيل ${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(color: AppColors.danger, fontFamily: 'Tajawal'),
                              ),
                            ],
                          ),
                        )
                          : TextField(
                              controller: _msgCtrl,
                              style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text),
                              decoration: InputDecoration(
                                hintText: 'اكتب رسالة...',
                                hintStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textSub),
                                filled: true,
                                fillColor: AppColors.bgCard2,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onLongPress: _startRecording,
                      onLongPressUp: _stopRecording,
                      child: IconButton(
                        onPressed: _sendMessage,
                        icon: Icon(
                          _msgCtrl.text.trim().isEmpty? Icons.mic_rounded : Icons.send_rounded,
                          color: AppColors.primary,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final MessageModel msg;
  final bool isMe;
  final AudioPlayer player;

  const _MessageBubble({required this.msg, required this.isMe, required this.player});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _isPlaying = false;

  String _fmtDur(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _playAudio() async {
    if (widget.msg.audioUrl == null) return;
    if (_isPlaying) {
      await widget.player.stop();
      setState(() => _isPlaying = false);
    } else {
      await widget.player.play(UrlSource(widget.msg.audioUrl!));
      setState(() => _isPlaying = true);
      widget.player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isMe? AppColors.primary : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isMe)
              Text(
                widget.msg.senderName?? 'مجهول',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textSub,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (widget.msg.type == MsgType.image && widget.msg.mediaUrl!= null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.msg.mediaUrl!,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              )
            else if (widget.msg.type == MsgType.audio)
              GestureDetector(
                onTap: _playAudio,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_isPlaying? Icons.stop_rounded : Icons.play_arrow_rounded,
                        color: widget.isMe? AppColors.white : AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      '🎤 ${_fmtDur(widget.msg.duration?? 0)}',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: widget.isMe? AppColors.white : AppColors.text,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                widget.msg.content,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  color: widget.isMe? AppColors.white : AppColors.text,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
