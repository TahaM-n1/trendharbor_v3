// lib/services/storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // Save like state for a post
  static Future<void> saveLikeState(String postId, bool liked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('post_$postId', liked);
  }

  // Load like state for a post
  static Future<bool> loadLikeState(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('post_$postId') ?? false;
  }
}
