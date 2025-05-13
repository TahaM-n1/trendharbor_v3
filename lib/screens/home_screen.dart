import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/bottom_navbar.dart';

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
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      // First try to get data from SharedPreferences (faster)
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
        return; // Exit early if we loaded from SharedPreferences
      }
      
      // If not in prefs, get from Firebase
      final User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        print('Fetching user data for UID: ${currentUser.uid}');
        // Fetch user data from Firestore
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists && mounted) {
          final username = userDoc.get('username') as String?;
          final accountType = userDoc.get('accountType') as String?;
          
          if (username != null && accountType != null) {
            // Save to preferences for future use
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
          // If no user is logged in, redirect to login screen
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
      
      // Get list of users that current user follows
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('following')
          .doc(currentUser.uid)
          .collection('userFollowing')
          .get();
      
      final List<String> followingUsers = followingSnapshot.docs
          .map((doc) => doc.id)
          .toList();
      
      // Always include current user's posts in the feed
      followingUsers.add(currentUser.uid);
      
      // If user doesn't follow anyone yet, show the most recent posts
      if (followingUsers.isEmpty) {
        await _loadRecentPosts();
        return;
      }
      
      // Query posts from followed users
      var query = FirebaseFirestore.instance
          .collection('posts')
          .where('userId', whereIn: followingUsers)
          .orderBy('timestamp', descending: true)
          .limit(_postsPerPage);
          
      final querySnapshot = await query.get();
      
      if (querySnapshot.docs.isEmpty) {
        // If no posts from followed users, load recent posts
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
      // Load recent posts
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
      
      // Get list of users that current user follows
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('following')
          .doc(currentUser.uid)
          .collection('userFollowing')
          .get();
      
      final List<String> followingUsers = followingSnapshot.docs
          .map((doc) => doc.id)
          .toList();
      
      // Always include current user's posts
      followingUsers.add(currentUser.uid);
      
      // If user doesn't follow anyone, load more recent posts
      if (followingUsers.isEmpty) {
        await _loadMoreRecentPosts();
        return;
      }
      
      // Query more posts from followed users
      var query = FirebaseFirestore.instance
          .collection('posts')
          .where('userId', whereIn: followingUsers)
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_postsPerPage);
          
      final querySnapshot = await query.get();
      
      if (querySnapshot.docs.isEmpty) {
        // If we've reached the end, reset to the beginning to loop
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
      // Load more recent posts
      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_postsPerPage)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        // If we've reached the end, reset to the beginning to loop
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
        context.go('/'); // Navigate back to login screen
      }
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TrendHarbor'),
        automaticallyImplyLeading: false,
        actions: [
          // Show user info in the app bar with dropdown menu
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
                        // Use profile picture if available
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
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 700, // Consistent width constraint with post detail screen
        ),
        child: Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0, // No shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0), // Square corners
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Post header with user info
              ListTile(
                leading: GestureDetector(
                  onTap: () => context.push('/profile/${post['userId']}'),
                  child: CircleAvatar(
                    backgroundImage: userProfileImage != null && userProfileImage.isNotEmpty
                        ? NetworkImage(userProfileImage)
                        : null,
                    child: userProfileImage == null || userProfileImage.isEmpty
                        ? Text(username[0].toUpperCase())
                        : null,
                  ),
                ),
                title: Text(
                  username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: timestamp != null
                    ? Text(_formatTimestamp(timestamp))
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ),
              
              // Post image with aspect ratio constraint
              GestureDetector(
                onTap: () => context.push('/post/${post['id']}'),
                child: AspectRatio(
                  aspectRatio: 1.0, // Square aspect ratio
                  child: Hero(
                    tag: 'post-${post['id']}',
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200], // Background color while loading
                      ),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              "${imageUrl}${imageUrl.contains('?') ? '&' : '?'}t=${DateTime.now().millisecondsSinceEpoch}",
                              fit: BoxFit.contain, // Changed to contain to avoid distortion
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
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
              ),
              
              // Post actions - now contained within the same width constraint
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite_border),
                      onPressed: () {
                        // Navigate to post detail to like
                        context.push('/post/${post['id']}');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () {
                        // Navigate to post detail to comment
                        context.push('/post/${post['id']}');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Share feature coming soon')),
                        );
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.bookmark_border),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Save feature coming soon')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              // Post stats and caption - now contained within the same width constraint
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$likes likes${comments > 0 ? ' • $comments comments' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              TextSpan(text: caption),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
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