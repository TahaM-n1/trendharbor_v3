import 'package:cloud_firestore/cloud_firestore.dart';

// Add this enum definition
enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  post_share,
}

class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final String type; // This will use a string representation instead of enum
  final String? mediaUrl;
  final Map<String, dynamic>? sharedPost;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isRead,
    this.type = 'text',
    this.mediaUrl,
    this.sharedPost,
  });
  
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      type: data['type'] ?? 'text',
      mediaUrl: data['mediaUrl'],
      sharedPost: data['sharedPost'],
    );
  }
}