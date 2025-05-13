import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart' as app_user;

class ChatService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Get all chats for the current user
  Stream<List<Chat>> getChats() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Chat> chats = [];
          
          for (var doc in snapshot.docs) {
            // Get chat data
            final chatData = doc.data();
            final List<dynamic> participants = chatData['participants'];
            
            // Get the other user's ID (not current user)
            final otherUserId = participants.firstWhere(
              (id) => id != currentUserId,
              orElse: () => currentUserId,
            );
            
            // Get the other user's data
            final userDoc = await _firestore.collection('users').doc(otherUserId).get();
            
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              
              // Create user model
              final user = app_user.User(
                id: otherUserId,
                username: userData['username'] ?? 'Unknown',
                profileImageUrl: userData['profileImageUrl'] ?? '',
              );
              
              // Create chat model
              final lastMessage = chatData['lastMessage']?['text'] ?? '';
              
              chats.add(Chat(
                id: doc.id,
                user: user,
                lastMessage: lastMessage,
                updatedAt: (chatData['updatedAt'] as Timestamp).toDate(),
              ));
            }
          }
          
          return chats;
        });
  }

  // Get messages for a specific chat
  Stream<List<Message>> getMessages(String chatId) {
    return _firestore
        .collection('messages')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Message(
              id: doc.id,
              senderId: data['senderId'],
              text: data['text'] ?? '',
              timestamp: (data['timestamp'] as Timestamp).toDate(),
              isRead: data['read'] ?? false,
              type: MessageType.values.firstWhere(
                (type) => type.name == (data['type'] ?? 'text'),
                orElse: () => MessageType.text,
              ),
              mediaUrl: data['mediaUrl'],
            );
          }).toList();
        });
  }

  // Create a new chat with another user
  Future<String> createChat(String otherUserId) async {
    if (currentUserId == null) {
      throw Exception('You must be logged in to create a chat');
    }

    // Check if chat already exists between these users
    final existingChatQuery = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    // Look through the results to find a chat with both users
    for (var doc in existingChatQuery.docs) {
      final participants = List<String>.from(doc.data()['participants']);
      if (participants.contains(otherUserId)) {
        // Chat already exists
        return doc.id;
      }
    }

    // Create a new chat
    final newChatRef = _firestore.collection('chats').doc();
    final now = FieldValue.serverTimestamp();
    
    await newChatRef.set({
      'participants': [currentUserId, otherUserId],
      'createdAt': now,
      'updatedAt': now,
    });

    // Initialize the messages collection
    await _firestore
        .collection('messages')
        .doc(newChatRef.id)
        .set({
          'participantsInfo': {
            currentUserId: true,
            otherUserId: true,
          }
        });

    return newChatRef.id;
  }

  // Send a message in a chat
  Future<void> sendMessage(String chatId, String text) async {
    if (currentUserId == null) {
      throw Exception('You must be logged in to send a message');
    }

    final now = FieldValue.serverTimestamp();

    // Add message to messages subcollection
    await _firestore
        .collection('messages')
        .doc(chatId)
        .collection('messages')
        .add({
          'senderId': currentUserId,
          'text': text,
          'timestamp': now,
          'read': false,
          'type': 'text',
        });

    // Update chat with last message
    await _firestore
        .collection('chats')
        .doc(chatId)
        .update({
          'lastMessage': {
            'text': text,
            'senderId': currentUserId,
            'timestamp': now,
          },
          'updatedAt': now,
        });
  }

  // Mark all messages in a chat as read
  Future<void> markMessagesAsRead(String chatId) async {
    if (currentUserId == null) return;

    final batch = _firestore.batch();
    
    // Get all unread messages not sent by current user
    final messagesQuery = await _firestore
        .collection('messages')
        .doc(chatId)
        .collection('messages')
        .where('read', isEqualTo: false)
        .where('senderId', isNotEqualTo: currentUserId)
        .get();

    // Mark each as read
    for (var doc in messagesQuery.docs) {
      batch.update(doc.reference, {'read': true});
    }

    // Commit the batch
    await batch.commit();
  }
  
  // Delete a chat
  Future<void> deleteChat(String chatId) async {
    await _firestore.collection('chats').doc(chatId).delete();
    
    // Delete all messages in the chat
    final messagesQuery = await _firestore
        .collection('messages')
        .doc(chatId)
        .collection('messages')
        .get();
    
    final batch = _firestore.batch();
    for (var doc in messagesQuery.docs) {
      batch.delete(doc.reference);
    }
    
    // Delete the messages document
    batch.delete(_firestore.collection('messages').doc(chatId));
    
    await batch.commit();
  }
}