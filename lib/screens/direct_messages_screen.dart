import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../models/chat_model.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart' as app_user; 

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
      return const Scaffold(
        body: Center(
          child: Text('You need to be logged in to view messages'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Direct Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showNewChatDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Chat>>(
        stream: chatService.getChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final chats = snapshot.data ?? [];
          
          if (chats.isEmpty) {
            return const Center(
              child: Text('No conversations yet. Start chatting!'),
            );
          }
          
          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return Dismissible(
                key: Key(chat.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
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
                },
                child: ListTile(
                  leading: _buildAvatar(chat.user),
                  title: Text(
                    chat.user.username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    _formatDate(chat.updatedAt),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => context.go('/chat/${chat.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildAvatar(user) {
    if (user.profileImageUrl.isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.blue.shade200,
        child: Text(
          user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    
    return CircleAvatar(
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
    final chatService = Provider.of<ChatService>(context, listen: false);
    
    // Text controller for search field
    final TextEditingController searchController = TextEditingController();
    
    // To store all users and filtered users
    List<app_user.User> allUsers = [];
    List<app_user.User> filteredUsers = [];
    
    // State for loading, error, etc.
    bool isLoading = true;
    String? errorMessage;
    
    // Function to search users
    void searchUsers(String query) {
      if (query.isEmpty) {
        filteredUsers = List.from(allUsers);
      } else {
        filteredUsers = allUsers
          .where((user) => 
            user.username.toLowerCase().contains(query.toLowerCase()))
          .toList();
      }
    }
    
    // Initial data loading
    try {
      // Fetch all users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, isNotEqualTo: chatService.currentUserId)
          .limit(50)
          .get();
          
      allUsers = usersSnapshot.docs
          .map((doc) {
            // Safely access fields with null checking
            final data = doc.data();
            return app_user.User(
              id: doc.id,
              username: data['username'] ?? 'Unknown',
              // Check if profileImageUrl exists, use empty string if not
              profileImageUrl: data.containsKey('profileImageUrl') ? data['profileImageUrl'] : '',
              // Add account type
              accountType: data['accountType'] ?? 'User',
            );
          })
          .toList();
      
      // Sort alphabetically by username
      allUsers.sort((a, b) => a.username.compareTo(b.username));
      
      filteredUsers = List.from(allUsers);
      isLoading = false;
    } catch (e) {
      print('Error loading users: $e'); // Add this for debugging
      errorMessage = 'Error loading users: $e';
      isLoading = false;
    }

    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Start a new conversation'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    // Search bar
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by username...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchUsers(value);
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    
                    // User list
                    Expanded(
                      child: isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : errorMessage != null
                          ? Center(child: Text(errorMessage!))
                          : filteredUsers.isEmpty
                            ? const Center(child: Text('No users found'))
                            : ListView.builder(
                                itemCount: filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final user = filteredUsers[index];
                                  return ListTile(
                                    leading: _buildAvatar(user),
                                    title: Text(user.username),
                                    // Add subtitle to display account type
                                    subtitle: Text(
                                      user.accountType,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    onTap: () async {
                                      try {
                                        // Show loading state
                                        setState(() {
                                          isLoading = true;
                                          errorMessage = null;
                                        });
                                        
                                        // Create or get the chat
                                        final String chatId = await chatService.createChat(user.id);
                                        
                                        // Close the dialog
                                        Navigator.of(dialogContext).pop();
                                        
                                        // Navigate to the chat screen
                                        if (context.mounted) {
                                          context.go('/chat/$chatId');
                                        }
                                      } catch (e) {
                                        // Update state to show error
                                        setState(() {
                                          isLoading = false;
                                          errorMessage = 'Error creating chat: $e';
                                        });
                                        print('Error creating chat: $e');
                                      }
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
          }
        );
      },
    ).then((_) {
      // Clean up
      searchController.dispose();
    });
  }
}
