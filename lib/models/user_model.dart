// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String username;
  final String profileImageUrl;
  final String accountType;
  final Map<String, bool> userCampaigns; // Track campaign invitations

  User({
    required this.id,
    required this.username,
    this.profileImageUrl = '',
    this.accountType = 'Personal',
    this.userCampaigns = const {}, // Default empty map
  });

  factory User.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return User(
      id: doc.id,
      username: data['username'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      accountType: data['accountType'] ?? 'Personal',
      userCampaigns: Map<String, bool>.from(data['userCampaigns'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'profileImageUrl': profileImageUrl,
      'accountType': accountType,
      'userCampaigns': userCampaigns,
    };
  }
}

// lib/services/user_service.dart
class UserData {
  final String userId;
  final String username;
  final String email;
  final String accountType;
  final String profileImageUrl;
  final bool isVerified;
  final Map<String, bool> userCampaigns; // Track campaign invitations

  UserData({
    required this.userId,
    required this.username,
    required this.email,
    required this.accountType,
    this.profileImageUrl = '',
    this.isVerified = false,
    this.userCampaigns = const {},
  });
}
