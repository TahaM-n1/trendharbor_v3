import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../models/chat_model.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart' as app_user;
import '../widgets/bottom_navbar.dart';

class DirectMessagesScreen extends StatefulWidget {
  const DirectMessagesScreen({super.key});

  @override
  State<DirectMessagesScreen> createState() => _DirectMessagesScreenState();
}

class _DirectMessagesScreenState extends State<DirectMessagesScreen> {
  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<ChatService>(context);
    final currentUserId = chatService.currentUserId;
    
    if (currentUserId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Not Logged In',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need to be logged in to view messages',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Direct Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'New Message',
            onPressed: () => _showNewChatDialog(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: StreamBuilder<List<Chat>>(
            stream: chatService.getChats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading messages',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please try again later',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              final chats = snapshot.data ?? [];
              
              if (chats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.blue.shade200,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No conversations yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start chatting with someone!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showNewChatDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('New Message'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          backgroundColor: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  final hasUnreadMessages = chat.lastMessage.contains('Shared a post with you');
                  return Dismissible(
                    key: Key(chat.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red.shade400,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Conversation'),
                          content: const Text('Are you sure you want to delete this conversation?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) {
                      chatService.deleteChat(chat.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Conversation deleted'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      elevation: 0,
                      color: hasUnreadMessages ? Colors.blue.shade50 : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: InkWell(
                        onTap: () => context.go('/chat/${chat.id}'),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            leading: Stack(
                              children: [
                                _buildAvatar(chat.user),
                                if (hasUnreadMessages)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.blue.shade500,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              chat.user.username,
                              style: TextStyle(
                                fontWeight: hasUnreadMessages ? FontWeight.bold : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                if (chat.lastMessage.contains('Shared a post with you'))
                                  const Icon(
                                    Icons.photo,
                                    size: 14,
                                    color: Colors.blue,
                                  ),
                                if (chat.lastMessage.contains('Shared a post with you'))
                                  const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    chat.lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: hasUnreadMessages ? Colors.black87 : Colors.grey.shade600,
                                      fontWeight: hasUnreadMessages ? FontWeight.w500 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatDate(chat.updatedAt),
                                  style: TextStyle(
                                    color: hasUnreadMessages ? Colors.blue.shade700 : Colors.grey.shade500,
                                    fontSize: 12,
                                    fontWeight: hasUnreadMessages ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                if (hasUnreadMessages) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade600,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'New',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
  
  Widget _buildAvatar(user) {
    if (user.profileImageUrl.isEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.blue.shade400,
        child: Text(
          user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      );
    }
    
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: user.profileImageUrl.startsWith('assets/')
          ? AssetImage(user.profileImageUrl)
          : NetworkImage(user.profileImageUrl) as ImageProvider,
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.difference(date).inDays == 0) {
      return DateFormat.jm().format(date); // Today, show time
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('E').format(date); // Within a week, show day name
    } else {
      return DateFormat.MMMd().format(date); // Earlier, show date
    }
  }

  Future<void> _showNewChatDialog(BuildContext context) async {
    final TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> allUsers = [];
    List<Map<String, dynamic>> filteredUsers = [];
    bool isLoading = true;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Function to search users
            void searchUsers(String query) {
              if (query.isEmpty) {
                setState(() {
                  filteredUsers = List.from(allUsers);
                });
              } else {
                setState(() {
                  filteredUsers = allUsers
                    .where((user) => 
                      user['username'].toString().toLowerCase().contains(query.toLowerCase()))
                    .toList();
                });
              }
            }
            
            // Load users only once when dialog opens
            if (isLoading) {
              FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, isNotEqualTo: Provider.of<ChatService>(context, listen: false).currentUserId)
                .limit(50)
                .get()
                .then((snapshot) {
                  final users = snapshot.docs.map((doc) {
                    final data = doc.data();
                    return {
                      'id': doc.id,
                      'username': data['username'] ?? 'Unknown',
                      'profileImageUrl': data['profileImageUrl'] ?? '',
                      'accountType': data['accountType'] ?? 'User',
                    };
                  }).toList();
                  
                  // Sort alphabetically by username
                  users.sort((a, b) => 
                    a['username'].toString().toLowerCase().compareTo(
                      b['username'].toString().toLowerCase()
                    )
                  );
                  
                  setState(() {
                    allUsers = users;
                    filteredUsers = List.from(users);
                    isLoading = false;
                  });
                })
                .catchError((error) {
                  setState(() {
                    errorMessage = 'Error loading users: $error';
                    isLoading = false;
                  });
                });
            }
            
            return AlertDialog(
              title: const Text('New Message'),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search users...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: searchUsers,
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                                  const SizedBox(height: 16),
                                  Text(
                                    errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : filteredUsers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No users found',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final user = filteredUsers[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.shade400,
                                      backgroundImage: user['profileImageUrl'] != null && 
                                                     user['profileImageUrl'].isNotEmpty
                                          ? NetworkImage(user['profileImageUrl'])
                                          : null,
                                      child: user['profileImageUrl'] == null || 
                                           user['profileImageUrl'].isEmpty
                                          ? Text(
                                              user['username'][0].toUpperCase(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            )
                                          : null,
                                    ),
                                    title: Text(user['username']),
                                    subtitle: Text(user['accountType']),
                                    onTap: () async {
                                      Navigator.pop(dialogContext);
                                      await _createChat(user['id']);
                                    },
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      searchController.dispose();
    });
  }

  Future<void> _createChat(String otherUserId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Opening conversation...'),
              ],
            ),
          );
        },
      );

      final chatService = Provider.of<ChatService>(context, listen: false);
      
      // Create or get existing chat
      final chatId = await chatService.createChat(otherUserId);
      
      // Close loading dialog and navigate to chat
      if (mounted) {
        Navigator.pop(context);
        context.go('/chat/$chatId');
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) {
        Navigator.pop(context);
        
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error creating chat: $e');
    }
  }
}
