import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/video_post_widget.dart';
import '../services/video_player_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  bool _initialLoadComplete = false;
  bool _isLoadingUserData = true;
  String _username = 'User';
  String _accountType = '';
  DocumentSnapshot? _lastDocument;
  static const int _postsPerPage = 10;

  Map<String, bool> _showLikeOverlay = {};
  Map<String, bool> _likedPosts = {};
  Map<String, bool> _expandedComments = {};
  Map<String, List<Map<String, dynamic>>> _postComments = {};
  Map<String, bool> _loadingComments = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    
    // Make sure we pause all videos when the screen is disposed
    try {
      if (mounted) {
        final videoService = Provider.of<VideoPlayerService>(context, listen: false);
        videoService.pauseAllVideos();
        print('Successfully paused all videos on home screen dispose');
      }
    } catch (e) {
      print('Error handling videos on dispose: $e');
    }
    
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefUsername = prefs.getString('username');
      final prefAccountType = prefs.getString('accountType');
      
      if (prefUsername != null && prefAccountType != null) {
        if (mounted) {
          setState(() {
            _username = prefUsername;
            _accountType = prefAccountType;
            _isLoadingUserData = false;
          });
        }
        print('Loaded user data from preferences: $_username - $_accountType');
        return;
      }
      
      final User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        print('Fetching user data for UID: ${currentUser.uid}');
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists && mounted) {
          final username = userDoc.get('username') as String?;
          final accountType = userDoc.get('accountType') as String?;
          
          if (username != null && accountType != null) {
            await prefs.setString('username', username);
            await prefs.setString('accountType', accountType);
            
            if (mounted) {
              setState(() {
                _username = username;
                _accountType = accountType;
                _isLoadingUserData = false;
              });
            }
            print('Stored user data in preferences: $username - $accountType');
          }
        } else {
          print('User document does not exist in Firestore');
          if (mounted) {
            setState(() {
              _isLoadingUserData = false;
            });
          }
        }
      } else {
        print('Current user is null');
        if (mounted) {
          setState(() {
            _isLoadingUserData = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/');
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
  }

  Future<void> _loadPosts() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) context.go('/');
        return;
      }
      
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('following')
          .doc(currentUser.uid)
          .collection('userFollowing')
          .get();
      
      final List<String> followingUsers = followingSnapshot.docs
          .map((doc) => doc.id)
          .toList();
      
      followingUsers.add(currentUser.uid);
      
      if (followingUsers.isEmpty) {
        await _loadRecentPosts();
        return;
      }
      
      var query = FirebaseFirestore.instance
          .collection('posts')
          .where('userId', whereIn: followingUsers)
          .orderBy('timestamp', descending: true)
          .limit(_postsPerPage);
          
      final querySnapshot = await query.get();
      
      if (querySnapshot.docs.isEmpty) {
        await _loadRecentPosts();
        return;
      }
      
      final posts = querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
      
      if (mounted) {
        setState(() {
          _posts = posts;
          _lastDocument = querySnapshot.docs.last;
          _isLoading = false;
          _initialLoadComplete = true;
        });
      }
    } catch (e) {
      print('Error loading posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _initialLoadComplete = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading posts: $e')),
        );
      }
    }
  }
  
  Future<void> _loadRecentPosts() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(_postsPerPage)
          .get();
      
      final posts = querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
      
      if (mounted) {
        setState(() {
          _posts = posts;
          _lastDocument = querySnapshot.docs.last;
          _isLoading = false;
          _initialLoadComplete = true;
        });
      }
    } catch (e) {
      print('Error loading recent posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _initialLoadComplete = true;
        });
      }
    }
  }
  
  Future<void> _loadMorePosts() async {
    if (_isLoading || _lastDocument == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('following')
          .doc(currentUser.uid)
          .collection('userFollowing')
          .get();
      
      final List<String> followingUsers = followingSnapshot.docs
          .map((doc) => doc.id)
          .toList();
      
      followingUsers.add(currentUser.uid);
      
      if (followingUsers.isEmpty) {
        await _loadMoreRecentPosts();
        return;
      }
      
      var query = FirebaseFirestore.instance
          .collection('posts')
          .where('userId', whereIn: followingUsers)
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_postsPerPage);
          
      final querySnapshot = await query.get();
      
      if (querySnapshot.docs.isEmpty) {
        _lastDocument = null;
        await _loadPosts();
        return;
      }
      
      final newPosts = querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
      
      if (mounted) {
        setState(() {
          _posts.addAll(newPosts);
          _lastDocument = querySnapshot.docs.last;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading more posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadMoreRecentPosts() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_postsPerPage)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        _lastDocument = null;
        await _loadPosts();
        return;
      }
      
      final newPosts = querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
      
      if (mounted) {
        setState(() {
          _posts.addAll(newPosts);
          _lastDocument = querySnapshot.docs.last;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading more recent posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMorePosts();
    }
  }
  
  Future<void> _refreshFeed() async {
    setState(() {
      _posts = [];
      _lastDocument = null;
    });
    
    await _loadPosts();
    return;
  }

  void _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  void _sharePostInDM(Map<String, dynamic> post) {
    // Check if widget is still mounted
    if (!mounted) return;
    
    final TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> allUsers = [];
    List<Map<String, dynamic>> filteredUsers = [];
    bool isLoading = true;
    String? errorMessage;
    
    // Use rootNavigator: true to ensure dialog is shown properly
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            
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
            
            if (isLoading) {
              FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, isNotEqualTo: FirebaseAuth.instance.currentUser?.uid)
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
              title: const Text('Share Post'),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search users...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: searchUsers,
                    ),
                    const SizedBox(height: 16),
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
                                    leading: CircleAvatar(
                                      backgroundImage: user['profileImageUrl'] != null && user['profileImageUrl'].isNotEmpty
                                          ? NetworkImage(user['profileImageUrl'])
                                          : null,
                                      child: user['profileImageUrl'] == null || user['profileImageUrl'].isEmpty
                                          ? Text(
                                              user['username'][0].toUpperCase(),
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            )
                                          : null,
                                    ),
                                    title: Text(user['username']),
                                    subtitle: Text(user['accountType']),
                                    onTap: () async {
                                      Navigator.pop(dialogContext);
                                      // Only proceed if widget is still mounted
                                      if (mounted) {
                                        await _sendPostToUser(user['id'], post);
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
          },
        );
      },
    ).then((_) {
      // Dispose controller safely
      searchController.dispose();
    });
  }

  Future<void> _sendPostToUser(String recipientId, Map<String, dynamic> post) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      // Check if widget is still mounted before showing dialog
      if (!mounted) return;
      
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
                Text('Sending post...'),
              ],
            ),
          );
        },
      );

      final chatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();
    
      // Check if widget is still mounted after async operation
      if (!mounted) return;
    
      String chatId = '';
    
      for (final doc in chatQuery.docs) {
        final List<dynamic> participants = doc['participants'];
        if (participants.contains(recipientId)) {
          chatId = doc.id;
          break;
        }
      }
    
      if (chatId.isEmpty) {
        final chatDoc = await FirebaseFirestore.instance.collection('chats').add({
          'participants': [currentUser.uid, recipientId],
          'lastMessage': {
            'text': 'Shared a post with you',
            'timestamp': FieldValue.serverTimestamp(),
            'senderId': currentUser.uid,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        chatId = chatDoc.id;
      } else {
        await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
          'lastMessage': {
            'text': 'Shared a post with you',
            'timestamp': FieldValue.serverTimestamp(),
            'senderId': currentUser.uid,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    
      // Create the shared post object
      final sharedPost = {
        'postId': post['id'],
        'mediaType': post['mediaType'] ?? 'image',
        'caption': post['caption'] ?? '',
        'username': post['username'],
      };
    
      // Add appropriate media URL based on type
      if (post['mediaType'] == 'video') {
        sharedPost['videoUrl'] = post['videoUrl'];
        sharedPost['thumbnailUrl'] = post['thumbnailUrl'] ?? '';
      } else {
        sharedPost['imageUrl'] = post['imageUrl'];
      }
    
      await FirebaseFirestore.instance.collection('messages').add({
        'chatId': chatId,
        'senderId': currentUser.uid,
        'text': 'Shared a post with you',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'post_share',
        'isRead': false,
        'sharedPost': sharedPost,
      });
    
      // Check if widget is still mounted before showing feedback
      if (!mounted) return;
    
      // Close the loading dialog
      Navigator.of(context, rootNavigator: true).pop();
    
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post shared successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Check if widget is still mounted before showing error feedback
      if (!mounted) return;
    
      // Close the loading dialog, using rootNavigator to ensure it's closed
      Navigator.of(context, rootNavigator: true).pop();
    
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing post: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error sharing post: $e');
    }
  }

  Future<void> _toggleLike(String postId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final bool isLiked = _likedPosts[postId] ?? false;
    final int postIndex = _posts.indexWhere((post) => post['id'] == postId);
    
    if (postIndex == -1) return;
    
    final likeRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(currentUser.uid);
    
    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId);
        
    try {
      setState(() {
        _likedPosts[postId] = !isLiked;
        
        if (!isLiked) {
          _posts[postIndex]['likes'] = (_posts[postIndex]['likes'] ?? 0) + 1;
        } else {
          _posts[postIndex]['likes'] = (_posts[postIndex]['likes'] ?? 1) - 1;
        }
      });
      
      if (isLiked) {
        await likeRef.delete();
        await postRef.update({
          'likes': FieldValue.increment(-1),
        });
      } else {
        await likeRef.set({
          'userId': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        await postRef.update({
          'likes': FieldValue.increment(1),
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
      
      setState(() {
        _likedPosts[postId] = isLiked;
        
        if (isLiked) {
          _posts[postIndex]['likes'] = (_posts[postIndex]['likes'] ?? 0) + 1;
        } else {
          _posts[postIndex]['likes'] = (_posts[postIndex]['likes'] ?? 1) - 1;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating like: $e')),
        );
      }
    }
  }

  void _showLikeAnimation(String postId) {
    if (!mounted) return;
  
    setState(() {
      _showLikeOverlay[postId] = true;
    });
    
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showLikeOverlay[postId] = false;
        });
      }
    });
  }

  Future<void> _loadLikeStatus(List<String> postIds) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    try {
      for (final postId in postIds) {
        final likeDoc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .collection('likes')
            .doc(currentUser.uid)
            .get();
            
        if (mounted) {
          setState(() {
            _likedPosts[postId] = likeDoc.exists;
          });
        }
      }
    } catch (e) {
      print('Error loading like status: $e');
    }
  }

  Future<void> _loadPostComments(String postId) async {
    if (_loadingComments[postId] == true || !mounted) return;
    
    setState(() {
      _loadingComments[postId] = true;
    });
    
    try {
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();
      
      final comments = commentsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      // Check if widget is still mounted before updating state
      if (!mounted) return;
      
      setState(() {
        _postComments[postId] = comments;
        _loadingComments[postId] = false;
      });
      
      print('Loaded ${comments.length} comments for post $postId');
    } catch (e) {
      print('Error loading comments for post $postId: $e');
      // Check if widget is still mounted before updating state
      if (!mounted) return;
      
      setState(() {
        _loadingComments[postId] = false;
        _postComments[postId] = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TrendHarbor'),
        automaticallyImplyLeading: false,
        actions: [
          _isLoadingUserData
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                )
              : PopupMenuButton<String>(
                  offset: const Offset(0, 50),
                  onSelected: (value) {
                    if (value == 'profile') {
                      context.go('/profile');
                    } else if (value == 'settings') {
                      context.go('/profile-settings');
                    } else if (value == 'logout') {
                      _signOut();
                    } else if (value == 'create-post') {
                      context.go('/create-post');
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _getUserProfileAvatar(),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _accountType,
                              style: const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          const Icon(Icons.person),
                          const SizedBox(width: 10),
                          const Text('View Profile'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'create-post',
                      child: Row(
                        children: [
                          const Icon(Icons.add_photo_alternate),
                          const SizedBox(width: 10),
                          const Text('Create Post'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'settings',
                      child: Row(
                        children: [
                          const Icon(Icons.settings),
                          const SizedBox(width: 10),
                          const Text('Settings'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          const Icon(Icons.logout, color: Colors.red),
                          const SizedBox(width: 10),
                          const Text('Logout', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => context.go('/direct-messages'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshFeed,
        child: !_initialLoadComplete 
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image_not_supported_outlined, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No posts to show',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Follow other users to see their posts in your feed',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.go('/explore'),
                        child: const Text('Explore Users'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _posts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _posts.length) {
                      return _isLoading
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(),
                          )
                        : const SizedBox();
                    }
                    
                    final post = _posts[index];
                    return _buildPostWidget(post);
                  },
                ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _getUserProfileAvatar() {
    String? profileImageUrl;
    
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        profileImageUrl = currentUser.photoURL;
      }
    } catch (e) {
      print('Error getting user profile image: $e');
    }
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.blue.shade200,
      backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
          ? NetworkImage(profileImageUrl)
          : null,
      child: profileImageUrl == null || profileImageUrl.isEmpty
          ? Text(
              _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
  
  Widget _buildPostWidget(Map<String, dynamic> post) {
    final imageUrl = post['imageUrl'];
    final username = post['username'] ?? 'Unknown User';
    final userProfileImage = post['userProfileImage'];
    final caption = post['caption'] ?? '';
    final likes = post['likes'] ?? 0;
    final comments = post['comments'] ?? 0;
    final timestamp = post['timestamp'] as Timestamp?;
    final postId = post['id'];
    
    _showLikeOverlay.putIfAbsent(postId, () => false);
    
    if (!_likedPosts.containsKey(postId)) {
      _loadLikeStatus([postId]);
    }
    
    final bool showComments = _expandedComments[postId] ?? false;
    
    // Check if comments should be loaded
    if (showComments) {
      // Only load if not already loading and not already loaded
      if (!(_loadingComments[postId] ?? false) && _postComments[postId] == null) {
        // Use a post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadPostComments(postId);
        });
      }
    }
    
    final bool isLiked = _likedPosts[postId] ?? false;
    final bool isLoadingComments = _loadingComments[postId] ?? false;
    final List<Map<String, dynamic>> postComments = _postComments[postId] ?? [];
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 700,
        ),
        child: Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () => context.push('/profile/${post['userId']}'),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue.shade300,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          backgroundImage: userProfileImage != null && userProfileImage.isNotEmpty
                              ? NetworkImage(userProfileImage)
                              : null,
                          backgroundColor: Colors.blue.shade100,
                          child: userProfileImage == null || userProfileImage.isEmpty
                              ? Text(username[0].toUpperCase())
                              : null,
                        ),
                      ),
                    ),
                    title: Text(
                      username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: timestamp != null
                        ? Text(
                            _formatTimestamp(timestamp),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
              
              // Media content
              GestureDetector(
                onDoubleTap: () {
                  _showLikeAnimation(postId);
                  if (!isLiked) {
                    _toggleLike(postId);
                  }
                },
                onTap: () => context.push('/post/${post['id']}'),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Check if it's a video post
                    post['mediaType'] == 'video'
                        ? SizedBox(
                            height: MediaQuery.of(context).size.width, // Make it square
                            child: VideoPostWidget(
                              postId: post['id'],
                              videoUrl: post['videoUrl'],
                              thumbnailUrl: post['thumbnailUrl'] ?? '',
                              autoplay: true,
                            ),
                          )
                        : AspectRatio(
                            aspectRatio: 1.0,
                            child: Hero(
                              tag: 'post-${post['id']}',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                ),
                                child: imageUrl != null && imageUrl.isNotEmpty
                                    ? Image.network(
                                        "${imageUrl}${imageUrl.contains('?') ? '&' : '?'}t=${DateTime.now().millisecondsSinceEpoch}",
                                        fit: BoxFit.contain,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                              color: Colors.blue.shade300,
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(Icons.broken_image, size: 50);
                                        },
                                      )
                                    : const Center(child: Icon(Icons.image, size: 50)),
                              ),
                            ),
                          ),

                    // Like animation overlay
                    AnimatedOpacity(
                      opacity: _showLikeOverlay[postId] ?? false ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: AnimatedScale(
                        scale: _showLikeOverlay[postId] ?? false ? 1.2 : 0.8,
                        duration: const Duration(milliseconds: 300),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 100,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade100,
                      blurRadius: 3,
                      spreadRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red.shade500 : Colors.grey.shade700,
                        size: 28,
                      ),
                      onPressed: () => _toggleLike(postId),
                      splashColor: Colors.red.shade100,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.comment_outlined,
                        color: Colors.grey.shade700,
                        size: 26,
                      ),
                      onPressed: () {
                        if (comments > 0) {
                          setState(() {
                            _expandedComments[postId] = !(_expandedComments[postId] ?? false);
                          });
                        } else {
                          context.push('/post/${post['id']}');
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.send,
                        color: Colors.grey.shade700,
                        size: 24,
                      ),
                      onPressed: () {
                        _sharePostInDM(post);
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.bookmark_border,
                        color: Colors.grey.shade700,
                        size: 26,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Save feature coming soon')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 16,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$likes likes',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (comments > 0 && !(_expandedComments[postId] ?? false)) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _expandedComments[postId] = true;
                          });
                        },
                        child: Text(
                          'View all $comments comments',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              if (caption.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade100,
                        width: 1,
                      ),
                    ),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 13,
                        height: 1.3,
                      ),
                      children: [
                        TextSpan(
                          text: username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: caption,
                          style: TextStyle(
                            height: 1.4,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
              if (_expandedComments[postId] ?? false) 
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Comments',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$comments',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.push('/post/${post['id']}'),
                              child: Text(
                                'See All',
                                style: TextStyle(color: Colors.blue.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      if (isLoadingComments)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue.shade300,
                          ),
                        )
                      else if (postComments.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          alignment: Alignment.center,
                          child: Text(
                            'No comments yet',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: postComments.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            indent: 68,
                            endIndent: 16,
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (context, index) {
                            final comment = postComments[index];
                            final commentTimestamp = comment['timestamp'] as Timestamp?;
                            
                            return Container(
                              decoration: BoxDecoration(
                                color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [Colors.blue.shade300, Colors.purple.shade300],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.shade300,
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.blue.shade50,
                                        backgroundImage: comment['userProfileImage'] != null && comment['userProfileImage'].isNotEmpty
                                            ? NetworkImage(comment['userProfileImage'])
                                            : null,
                                        child: comment['userProfileImage'] == null || comment['userProfileImage'].isEmpty
                                            ? Text(
                                                (comment['username'] ?? 'U')[0].toUpperCase(),
                                                style: TextStyle(
                                                  color: Colors.blue.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                comment['username'] ?? 'Unknown User',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                commentTimestamp != null 
                                                    ? _formatTimestamp(commentTimestamp) 
                                                    : 'No timestamp',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: const BorderRadius.only(
                                                topRight: Radius.circular(16),
                                                bottomLeft: Radius.circular(16),
                                                bottomRight: Radius.circular(16),
                                              ),
                                            ),
                                            child: Text(
                                              comment['text'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                height: 1.3,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6, left: 4),
                                            child: Row(
                                              children: [
                                                Text(
                                                  'Like',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Text(
                                                  'Reply',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () => context.push('/post/${post['id']}'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.blue.shade50,
                                  backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null
                                      ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                                      : null,
                                  child: FirebaseAuth.instance.currentUser?.photoURL == null
                                      ? Text(
                                          FirebaseAuth.instance.currentUser?.displayName?.isNotEmpty == true
                                              ? FirebaseAuth.instance.currentUser!.displayName![0].toUpperCase()
                                              : 'U',
                                          style: TextStyle(
                                            color: Colors.blue.shade800,
                                            fontSize: 12,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Add a comment...',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
              const SizedBox(height: 12),
              if (!(_expandedComments[postId] ?? false))
                const Divider(height: 1, thickness: 0.5),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}