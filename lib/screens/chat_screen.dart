import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';

import '../models/chat_model.dart'; 
import '../models/user_model.dart'; 

class ChatScreen extends StatefulWidget {
  final String chatId;
  
  const ChatScreen({
    super.key,
    required this.chatId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening the chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    await chatService.markMessagesAsRead(widget.chatId);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      await chatService.sendMessage(widget.chatId, text);
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<ChatService>(context);
  _currentUserId = chatService.currentUserId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<List<Chat>>(
          stream: chatService.getChats(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Text('Chat');
            }
            
            final chats = snapshot.data!;
            final chat = chats.firstWhere(
              (c) => c.id == widget.chatId,
              orElse: () => Chat(
                id: widget.chatId,
                user: User(id: '', username: 'Chat', profileImageUrl: ''),
                lastMessage: '',
                updatedAt: DateTime.now(),
              ),
            );
            
            return Row(
              children: [
                _buildAvatar(chat.user),
                const SizedBox(width: 10),
                Text(chat.user.username),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hello!'),
                  );
                }
                
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageItem(message);
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

  Widget _buildMessageItem(Message message) {
    final isMine = message.senderId == _currentUserId;
    
    if (message.type == 'post_share') {
      // This is a shared post message
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: isMine ? Colors.blue.shade100 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shared a post from ${message.sharedPost?['username'] ?? 'Unknown'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  if (message.sharedPost != null && message.sharedPost?['postId'] != null) {
                    context.push('/post/${message.sharedPost!['postId']}');
                  }
                },
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: message.sharedPost != null && message.sharedPost?['imageUrl'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            message.sharedPost!['imageUrl'] as String,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, _) => const Center(
                              child: Icon(Icons.broken_image, size: 40),
                            ),
                          ),
                        )
                      : const Center(child: Icon(Icons.image, size: 40)),
                ),
              ),
              if (message.sharedPost != null && 
                  message.sharedPost?['caption'] != null && 
                  message.sharedPost!['caption'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    message.sharedPost!['caption'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  _formatTimestamp(message.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Regular message bubble
    final bubbleColor = isMine ? Colors.blue.shade100 : Colors.grey.shade200;
    final textColor = isMine ? Colors.blue.shade800 : Colors.black87;
    final alignment = isMine ? MainAxisAlignment.end : MainAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: isMine 
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(color: textColor, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.jm().format(message.timestamp),
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () {
              // TODO: Implement file attachment
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: _isLoading 
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: _isLoading ? null : _sendMessage,
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
  
  Widget _buildAvatar(user) {
    if (user.profileImageUrl.isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.blue.shade200,
        child: Text(
          user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    
    return CircleAvatar(
      backgroundImage: user.profileImageUrl.startsWith('assets/')
          ? AssetImage(user.profileImageUrl)
          : NetworkImage(user.profileImageUrl) as ImageProvider,
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat.jm().format(timestamp);
  }
}