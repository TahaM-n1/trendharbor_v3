// lib/models/user_model.dart
class User {
  final String id;
  final String username;
  final String profileImageUrl;
  final String accountType; // New field for account type

  User({
    required this.id,
    required this.username,
    this.profileImageUrl = '',
    this.accountType = 'Personal', // Add this parameter with a default value
  });
}

// lib/services/user_service.dart
class UserData {
  final String userId;
  final String username;
  final String email;
  final String accountType;
  final String profileImageUrl;
  final bool isVerified;

  UserData({
    required this.userId,
    required this.username, 
    required this.email,
    required this.accountType,
    this.profileImageUrl = '',  // Default empty string
    this.isVerified = false,    // Default to false
  });
}
