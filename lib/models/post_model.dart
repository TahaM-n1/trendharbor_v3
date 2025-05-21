// lib/models/post_model.dart
import 'user_model.dart';

class Post {
  final User user;
  final String? imageUrl;
  final String? videoUrl;
  final String caption;
  int likes;
  final int comments;
  bool liked;
  final String type; // 'image' or 'video'

  Post({
    required this.user,
    this.imageUrl,
    this.videoUrl,
    required this.caption,
    required this.likes,
    required this.comments,
    this.liked = false,
    required this.type,
  });
}
