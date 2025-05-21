// lib/models/post_model.dart
import 'user_model.dart';

class Post {
  final User user;
  final String imageUrl;
  final String caption;
  int likes;
  final int comments;
  bool liked; // Add this field

  Post({
    required this.user,
    required this.imageUrl,
    required this.caption,
    required this.likes,
    required this.comments,
    this.liked = false, // Default to false
  });
}
