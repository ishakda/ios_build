import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:untitled1/core/localization/app_localizations.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';
import 'package:untitled1/core/widgets/app_empty_state.dart';
import 'package:untitled1/core/widgets/app_gradient_scaffold.dart';
import 'package:untitled1/features/chat/domain/entities/message.dart';
import 'package:untitled1/features/chat/domain/repositories/chat_repository.dart';
import 'package:untitled1/injection_container.dart';

class ChatPage extends StatefulWidget {
  final String currentUserId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImageUrl;
  final String otherUserRole;

  const ChatPage({
    super.key,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImageUrl,
    this.otherUserRole = 'buyer',
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isMarkingRead = false;

  @override
  void initState() {
    super.initState();
    _markConversationRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_isSending || (_messageController.text.trim().isEmpty)) {
      return;
    }

    final message = Message(
      id: '',
      senderId: widget.currentUserId,
      receiverId: widget.otherUserId,
      text: _messageController.text.trim(),
      timestamp: DateTime.now(),
    );

    _send(message);
  }

  Future<void> _sendImage() async {
    if (_isSending) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    setState(() => _isSending = true);

    try {
      final imageUrl = await sl<ChatRepository>().uploadChatImage(
        File(image.path),
        currentUserId: widget.currentUserId,
        otherUserId: widget.otherUserId,
      );
      final message = Message(
        id: '',
        senderId: widget.currentUserId,
        receiverId: widget.otherUserId,
        text: '',
        imageUrl: imageUrl,
        timestamp: DateTime.now(),
      );
      await sl<ChatRepository>().sendMessage(message);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.translate('image_send_error')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _send(Message message) async {
    setState(() => _isSending = true);
    try {
      await sl<ChatRepository>().sendMessage(message);
      _messageController.clear();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.translate('message_send_error')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _markConversationRead() async {
    if (_isMarkingRead) {
      return;
    }
    _isMarkingRead = true;
    try {
      await sl<ChatRepository>().markConversationRead(
        currentUserId: widget.currentUserId,
        otherUserId: widget.otherUserId,
      );
    } catch (_) {
      // Best-effort update for read state.
    } finally {
      _isMarkingRead = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppGradientScaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              backgroundImage: widget.otherUserImageUrl != null
                  ? NetworkImage(widget.otherUserImageUrl!)
                  : null,
              child: widget.otherUserImageUrl == null
                  ? Icon(
                      widget.otherUserRole == 'seller'
                          ? AppIcons.seller
                          : AppIcons.user,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: sl<ChatRepository>().getMessages(
                widget.currentUserId,
                widget.otherUserId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return AppEmptyState(
                    icon: AppIcons.warning,
                    title: context.translate('conversation_unavailable'),
                    subtitle: context.translate('conversation_load_error'),
                    accentColor: Colors.redAccent,
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return AppEmptyState(
                    icon: AppIcons.chatEmpty,
                    title: context.translate('no_messages_yet'),
                    subtitle: context
                        .translate('say_hello_to')
                        .replaceAll('{name}', widget.otherUserName),
                  ).animate().fade().scale();
                }

                final messages = snapshot.data!;
                final hasUnreadIncoming = messages.any(
                  (m) => m.senderId == widget.otherUserId && !m.isRead,
                );
                if (hasUnreadIncoming) {
                  _markConversationRead();
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == widget.currentUserId;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: message.imageUrl != null
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (message.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  message.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (_, _, _) => Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: const Icon(AppIcons.imageBroken),
                  ),
                ),
              ),
            if (message.text.isNotEmpty)
              Padding(
                padding: message.imageUrl != null
                    ? const EdgeInsets.fromLTRB(12, 8, 12, 4)
                    : EdgeInsets.zero,
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Padding(
              padding: message.imageUrl != null
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
                  : EdgeInsets.zero,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Icon(
                      message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 12,
                      color: message.isRead ? Colors.lightGreenAccent : Colors.white70,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideX(begin: isMe ? 0.2 : -0.2),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _isSending ? null : _sendImage,
              icon: const Icon(AppIcons.image, color: AppColors.primary),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: context.translate('write_message_hint'),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: AnimatedContainer(
                duration: 180.ms,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSending
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(AppIcons.send, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
