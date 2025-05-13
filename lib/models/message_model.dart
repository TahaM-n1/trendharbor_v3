enum MessageType { text, image, audio }

class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;
  final String? mediaUrl;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isRead,
    this.type = MessageType.text,
    this.mediaUrl,
  });

  bool get isSentByMe => senderId == 'currentUserId'; // Replace in the UI
}