import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:trendharbor_v2/services/user_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/bottom_navbar.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../services/chat_service.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  
  const ProfileScreen({
    super.key,
    this.userId, // If null, show current user's profile
  });
  
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  String _currentUserId = '';
  bool _isCurrentUser = true;
  List<Map<String, dynamic>> _userPosts = [];
  List<Map<String, dynamic>> _likedPosts = [];
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;
  String _accountType = 'Personal'; // Default account type
  bool _isLoadingLiked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData().then((_) => _loadLikedPosts());
    
    // Listen for tab changes to load data only when needed
    _tabController.addListener(() {
      if (_tabController.index == 1 && _likedPosts.isEmpty && !_isLoadingLiked) {
        _loadLikedPosts();
      }
    });

    // Set up a timer to refresh user data periodically
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _isCurrentUser) {
        Provider.of<UserService>(context, listen: false).refreshUserData();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First try to get the current user from Firebase Auth
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not logged in'))
          );
          context.go('/'); // Redirect to login if not logged in
          return;
        }
      }

      _currentUserId = currentUser!.uid;
      
      // Determine which user profile to show
      final targetUserId = widget.userId ?? _currentUserId;
      _isCurrentUser = targetUserId == _currentUserId;

      // Get user data from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get();
      
      if (!userDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found'))
          );
          context.go('/home');
        }
        return;
      }

      // Get user posts
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: targetUserId)
          .orderBy('timestamp', descending: true)
          .get();
      
      final posts = postsSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      // Get followers and following counts
      final followersSnapshot = await FirebaseFirestore.instance
          .collection('followers')
          .doc(targetUserId)
          .collection('userFollowers')
          .get();
          
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('following')
          .doc(targetUserId)
          .collection('userFollowing')
          .get();

      // Check if current user is following this profile
      bool isFollowing = false;
      if (!_isCurrentUser) {
        final followDoc = await FirebaseFirestore.instance
            .collection('following')
            .doc(_currentUserId)
            .collection('userFollowing')
            .doc(targetUserId)
            .get();
        isFollowing = followDoc.exists;
      }

      if (mounted) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _userData = {
            'id': targetUserId,
            ...userData,
          };
          _userPosts = posts;
          _followersCount = followersSnapshot.docs.length;
          _followingCount = followingSnapshot.docs.length;
          _postsCount = posts.length;
          _isFollowing = isFollowing;
          _accountType = userData['accountType'] ?? 'Personal';
          _isLoading = false;
        });
        print("Loaded profile image URL: ${_userData?['profileImageUrl']}");
      }
    } catch (e) {
      print('Error loading profile data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e'))
        );
      }
    }
  }

  Future<void> _loadLikedPosts() async {
    if (!_isCurrentUser && _userData == null) return;
    
    final String userId = _isCurrentUser ? _currentUserId : _userData!['id'];
    
    setState(() {
      _isLoadingLiked = true;
    });
    
    try {
      // Modified query to include timestamp field along with userId
      final likesQuery = await FirebaseFirestore.instance
        .collectionGroup('likes')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true) // Adding timestamp as a second field
        .get();
        
      if (likesQuery.docs.isEmpty) {
        setState(() {
          _likedPosts = [];
          _isLoadingLiked = false;
        });
        return;
      }
      
      // Extract post IDs from likes
      final postIds = likesQuery.docs.map((doc) {
        // The parent of a like document is the 'likes' collection, and its parent is the post document
        return doc.reference.parent.parent!.id;
      }).toList();
      
      // Fetch the actual posts
      final List<Map<String, dynamic>> posts = [];
      
      // Process posts in batches to avoid excessive reads
      const batchSize = 10;
      for (var i = 0; i < postIds.length; i += batchSize) {
        final end = (i + batchSize < postIds.length) ? i + batchSize : postIds.length;
        final batch = postIds.sublist(i, end);
        
        // Get the posts for this batch
        final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
          
        // Add to our posts list
        posts.addAll(postsSnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList());
      }
      
      // Sort by most recently liked
      posts.sort((a, b) {
        final aTimestamp = a['timestamp'] as Timestamp?;
        final bTimestamp = b['timestamp'] as Timestamp?;
        if (aTimestamp == null || bTimestamp == null) return 0;
        return bTimestamp.compareTo(aTimestamp); // Newest first
      });
      
      if (mounted) {
        setState(() {
          _likedPosts = posts;
          _isLoadingLiked = false;
        });
        print("Loaded ${_likedPosts.length} liked posts");
      }
    } catch (e) {
      print('Error loading liked posts: $e');
      if (mounted) {
        setState(() {
          _isLoadingLiked = false;
          _likedPosts = [];
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      // Show a loading dialog first
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Selecting image...'),
              ],
            ),
          );
        },
      );
      
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      // Close the loading dialog once image is picked (or canceled)
      if (mounted) Navigator.of(context).pop();
      
      // User canceled image picking
      if (pickedFile == null) return;
      
      // Show another loading dialog for the upload process
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading image...'),
                ],
              ),
            );
          },
        );
      }

      // Store the old profile image URL for deletion after upload success
      String? oldImageUrl = _userData?['profileImageUrl'];
      
      // Create a reference to Firebase Storage
      final String fileName = '${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(fileName);
      
      String downloadUrl;
      
      // Handle upload differently based on platform
      if (kIsWeb) {
        print("Uploading image on Web platform");
        
        // Get file bytes for web
        final bytes = await pickedFile.readAsBytes();
        print("File read as bytes: ${bytes.length} bytes");
        
        // Upload bytes directly to Firebase Storage
        final uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        
        try {
          final taskSnapshot = await uploadTask;
          downloadUrl = await taskSnapshot.ref.getDownloadURL();
        } catch (e) {
          print("Error in web upload: $e");
          // Close dialog on error
          if (mounted) Navigator.of(context).pop();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: $e')),
            );
          }
          return;
        }
      } else {
        print("Uploading image on Mobile platform");
        // Mobile approach
        final File imageFile = File(pickedFile.path);
        final uploadTask = storageRef.putFile(imageFile);
        
        try {
          final taskSnapshot = await uploadTask;
          downloadUrl = await taskSnapshot.ref.getDownloadURL();
        } catch (e) {
          print("Error in mobile upload: $e");
          // Close dialog on error
          if (mounted) Navigator.of(context).pop();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: $e')),
            );
          }
          return;
        }
      }
      
      // Update Firestore with new image URL
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .update({'profileImageUrl': downloadUrl});
      
      // Update shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profileImageUrl', downloadUrl);
      
      // Update UserService
      final userService = Provider.of<UserService>(context, listen: false);
      await userService.updateProfileImageUrl(downloadUrl);

      // Clear the image cache
      _clearImageCache(downloadUrl);

      // Update local state to display the new image immediately
      if (mounted) {
        setState(() {
          if (_userData != null) {
            _userData = {
              ..._userData!,
              'profileImageUrl': downloadUrl,
            };
          }
        });
      }
      
      // Delete the old profile image if it exists
      await _deleteOldProfileImage(oldImageUrl);
      
      // Print debug information
      print("Profile image updated successfully");
      print("Download URL: $downloadUrl");
      print("Updated _userData: ${_userData}");
      
      // Close dialog
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error during image upload process: $e');
      
      // Close any dialog
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteOldProfileImage(String? oldImageUrl) async {
    if (oldImageUrl == null || oldImageUrl.isEmpty) {
      print("No old profile image to delete");
      return;
    }

    try {
      // Check if it's a Firebase Storage URL
      if (!oldImageUrl.contains('firebasestorage.googleapis.com')) {
        print("Not a Firebase Storage URL: $oldImageUrl");
        return;
      }
      
      print("Original URL to delete: $oldImageUrl");
      
      try {
        // The most reliable way to parse Firebase Storage URLs
        // The format is: https://firebasestorage.googleapis.com/v0/b/BUCKET/o/ENCODED_PATH?alt=media&token=TOKEN
        
        // Extract the encoded path
        final encodedPath = oldImageUrl.split('/o/').last.split('?').first;
        // Decode it to get the actual file path
        final decodedPath = Uri.decodeComponent(encodedPath);
        
        print("Parsed path for deletion: $decodedPath");
        
        final storageRef = FirebaseStorage.instance.ref(decodedPath);
        await storageRef.delete();
        print("Successfully deleted old profile image: $decodedPath");
      } catch (e) {
        print("First deletion attempt failed: $e");
        
        // Fallback to direct path approach
        try {
          final fileName = oldImageUrl.split('/').last.split('?').first;
          final folderPath = 'profile_images';
          final fullPath = '$folderPath/$fileName';
          
          print("Attempting fallback deletion with path: $fullPath");
          
          final storageRef = FirebaseStorage.instance.ref(fullPath);
          await storageRef.delete();
          print("Successfully deleted old profile image with fallback method: $fullPath");
        } catch (e2) {
          print("Fallback deletion also failed: $e2");
          throw e2;
        }
      }
    } catch (e) {
      // Don't throw an error if deletion fails
      // Just log it since the primary operation (uploading new image) succeeded
      print("Error deleting old profile image: $e");
    }
  }

  Future<void> _toggleFollow() async {
    if (_isCurrentUser || _userData == null) return;

    final targetUserId = _userData!['id'];
    
    try {
      if (_isFollowing) {
        // Unfollow
        await FirebaseFirestore.instance
            .collection('following')
            .doc(_currentUserId)
            .collection('userFollowing')
            .doc(targetUserId)
            .delete();

        await FirebaseFirestore.instance
            .collection('followers')
            .doc(targetUserId)
            .collection('userFollowers')
            .doc(_currentUserId)
            .delete();
      } else {
        // Follow
        await FirebaseFirestore.instance
            .collection('following')
            .doc(_currentUserId)
            .collection('userFollowing')
            .doc(targetUserId)
            .set({
              'timestamp': FieldValue.serverTimestamp(),
            });

        await FirebaseFirestore.instance
            .collection('followers')
            .doc(targetUserId)
            .collection('userFollowers')
            .doc(_currentUserId)
            .set({
              'timestamp': FieldValue.serverTimestamp(),
            });
      }

      setState(() {
        if (_isFollowing) {
          _followersCount--;
        } else {
          _followersCount++;
        }
        _isFollowing = !_isFollowing;
      });
    } catch (e) {
      print('Error toggling follow status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating follow status: $e'))
      );
    }
  }

  Future<void> _navigateToDirectMessage() async {
    if (_userData == null) return;
    
    final targetUserId = _userData!['id'];
    
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
    
    try {
      // Get chat service
      final chatService = Provider.of<ChatService>(context, listen: false);
      
      // Create or get existing chat
      final chatId = await chatService.createChat(targetUserId);
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      // Navigate to chat screen
      if (mounted) {
        context.go('/chat/$chatId');
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error creating chat: $e');
    }
  }

  void _clearImageCache(String imageUrl) {
    // Clear image from cache to ensure the latest version is loaded
    print("Clearing cache for image: $imageUrl");
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // Force widget rebuild
    if (mounted) {
      setState(() {
        // This empty setState forces a rebuild
      });
    }
  }

  Future<bool> _checkImageExists(String imageUrl) async {
    try {
      final response = await http.head(Uri.parse(imageUrl));
      return response.statusCode == 200;
    } catch (e) {
      print("Error checking image existence: $e");
      return false;
    }
  }

  double _calculateTabContentHeight() {
    if (_tabController.index == 0) {
      // Posts tab
      return _userPosts.isEmpty ? 300 : (_userPosts.length / 3).ceil() * 160;
    } else if (_tabController.index == 1) {
      // Liked posts tab
      return _likedPosts.isEmpty ? 300 : (_likedPosts.length / 3).ceil() * 160;
    } else {
      // Saved posts tab (no real content yet)
      return 300;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final userService = Provider.of<UserService>(context);
    final username = _userData?['username'] ?? 'User';
    final bio = _userData?['bio'] ?? '';
    final profileImageUrl = _userData?['profileImageUrl'];
    final isVerified = _userData?['isVerified'] ?? false;
    final accountType = _userData?['accountType'] ?? 'Personal';

    return Scaffold(
      appBar: AppBar(
        title: Text(username),
        automaticallyImplyLeading: !_isCurrentUser,
        actions: [
          if (_isCurrentUser)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => context.push('/profile-settings'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false, // This disables the scrollbar
            ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Profile Header - Responsive layout
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Use row layout on large screens, column on small
                        final isLargeScreen = constraints.maxWidth > 600;
                        
                        if (isLargeScreen) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column with profile image
                              Column(
                                children: [
                                  _buildProfileImage(username, profileImageUrl),
                                  const SizedBox(height: 16),
                                  // Username and badge for large screens
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        username,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                      if (isVerified)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 4.0),
                                          child: Icon(
                                            Icons.verified,
                                            color: Colors.blue,
                                            size: 18,
                                          ),
                                        ),
                                    ],
                                  ),
                                  // Account type badge
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      accountType,
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 32),
                              
                              // Right column with stats and bio
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Stats in horizontal row
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildStatColumn(_postsCount, 'Posts'),
                                          _buildStatsVerticalDivider(),
                                          _buildStatColumn(_followersCount, 'Followers'),
                                          _buildStatsVerticalDivider(),
                                          _buildStatColumn(_followingCount, 'Following'),
                                        ],
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    // Bio with header
                                    if (bio.isNotEmpty) ...[
                                      Text(
                                        'Bio',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          bio,
                                          style: TextStyle(
                                            height: 1.4,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                    
                                    // Action buttons
                                    _isCurrentUser
                                        ? _buildCurrentUserButtons()
                                        : _buildOtherUserButtons(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Mobile layout (original layout with some improvements)
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Profile Image
                                  _buildProfileImage(username, profileImageUrl),
                                  const SizedBox(width: 24),
                                  
                                  // Stats
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildStatColumn(_postsCount, 'Posts'),
                                          _buildStatColumn(_followersCount, 'Followers'),
                                          _buildStatColumn(_followingCount, 'Following'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Username and verified badge
                              Row(
                                children: [
                                  Text(
                                    username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (isVerified)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4.0),
                                      child: Icon(
                                        Icons.verified,
                                        color: Colors.blue,
                                        size: 16,
                                      ),
                                    ),
                                  const Spacer(),
                                  // Account type badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      accountType,
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Bio
                              if (bio.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                                  child: Text(bio),
                                ),
                              
                              const SizedBox(height: 16),
                              
                              // Action buttons
                              _isCurrentUser
                                  ? _buildCurrentUserButtons()
                                  : _buildOtherUserButtons(),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                  
                  // Tab section
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        // Tabs
                        TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.blue.shade700,
                          labelColor: Colors.black,
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.grid_on),
                              text: "Posts",
                            ),
                            Tab(
                              icon: Icon(Icons.favorite_border),
                              text: "Likes",
                            ),
                            Tab(
                              icon: Icon(Icons.bookmark_border),
                              text: "Saved",
                            ),
                          ],
                        ),
                        
                        // Tab content - Dynamic height grid
                        SizedBox(
                          height: _calculateTabContentHeight(),
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Posts grid
                              _buildPostsGrid(),
                              
                              // Liked posts grid
                              _buildLikedPostsGrid(),
                              
                              // Saved posts grid
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.bookmark, size: 48, color: Colors.grey.shade300),
                                    const SizedBox(height: 16),
                                    const Text(
                                      "Saved posts will appear here",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
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
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _buildUserAvatar(String username) {
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.blue.shade200,
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStatColumn(int count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentUserButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () => context.push('/profile-settings')
                            .then((_) => _loadProfileData()),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
          ),
          child: const Text('Edit Profile'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/create-post'),
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Create Post'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            side: BorderSide(color: Colors.blue.shade700),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherUserButtons() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: ElevatedButton(
            onPressed: _toggleFollow,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isFollowing ? Colors.white : Colors.blue.shade700,
              foregroundColor: _isFollowing ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: _isFollowing 
                    ? BorderSide(color: Colors.grey.shade300)
                    : BorderSide.none,
              ),
            ),
            child: Text(_isFollowing ? 'Following' : 'Follow'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: OutlinedButton(
            onPressed: _navigateToDirectMessage,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(color: Colors.blue.shade700),
            ),
            child: const Text('Message'),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsGrid() {
    if (_userPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No posts yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (_isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/create-post'),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Create Your First Post'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.blue.shade700,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        final imageUrl = post['imageUrl'];
        
        return GestureDetector(
          onTap: () {
            // Navigate to post detail view
            context.push('/post/${post['id']}');
          },
          child: Hero(
            tag: 'post-${post['id']}',
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      "${imageUrl}${imageUrl.contains('?') ? '&' : '?'}t=${DateTime.now().millisecondsSinceEpoch}",
                      key: ValueKey(imageUrl),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / 
                                  loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 32,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Icon(
                        Icons.image,
                        size: 32,
                        color: Colors.grey,
                      ),
                    ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLikedPostsGrid() {
    if (_isLoadingLiked) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_likedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No liked posts yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Posts you like will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _likedPosts.length,
      itemBuilder: (context, index) {
        final post = _likedPosts[index];
        final imageUrl = post['imageUrl'];
        
        return GestureDetector(
          onTap: () {
            // Navigate to post detail view
            context.push('/post/${post['id']}');
          },
          child: Hero(
            tag: 'liked-post-${post['id']}',
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Post image
                    imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          "${imageUrl}${imageUrl.contains('?') ? '&' : '?'}t=${DateTime.now().millisecondsSinceEpoch}",
                          key: ValueKey("liked-$imageUrl"),
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / 
                                      loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 32,
                                color: Colors.grey,
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Icon(
                            Icons.image,
                            size: 32,
                            color: Colors.grey,
                          ),
                        ),
                    
                    // Username overlay at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Text(
                          post['username'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    
                    // Heart icon overlay in top-right
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildProfileImage(String username, String? profileImageUrl) {
    return GestureDetector(
      onTap: _isCurrentUser ? _pickAndUploadImage : null,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blue.shade700,
                width: 3,
              ),
            ),
            child: ClipOval(
              child: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                ? FutureBuilder<bool>(
                    future: _checkImageExists(profileImageUrl),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final imageExists = snapshot.data ?? false;
                      
                      if (imageExists) {
                        final randomParam = Random().nextInt(1000000);
                        
                        return Image(
                          image: NetworkImage('$profileImageUrl&cache=$randomParam'),
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
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
                            print("Error loading profile image with Image widget: $error");
                            return _buildUserAvatar(username);
                          },
                        );
                      } else {
                        print("Image URL exists but cannot be loaded: $profileImageUrl");
                        return _buildUserAvatar(username);
                      }
                    })
                : _buildUserAvatar(username),
            ),
          ),
          if (_isCurrentUser)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}