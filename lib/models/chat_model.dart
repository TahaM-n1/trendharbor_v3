import 'user_model.dart';

class Chat {
  final String id;
  final User user;
  final String lastMessage;
  final DateTime updatedAt;

  Chat({
    required this.id,
    required this.user,
    required this.lastMessage,
    required this.updatedAt,
  });
}