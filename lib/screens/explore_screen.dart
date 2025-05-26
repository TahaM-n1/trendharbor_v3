// lib/screens/explore_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../services/video_player_service.dart';
import '../widgets/bottom_navbar.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _accountType = 'personal';
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  DocumentSnapshot? _lastDocument;
  bool _hasMorePosts = true;
  static const int _postsPerPage = 30;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPosts();

    // Add scroll listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent * 0.8 &&
          !_isLoading &&
          _hasMorePosts) {
        _loadMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Stop all videos when leaving the explore screen
    Provider.of<VideoPlayerService>(context, listen: false).pauseAllVideos();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accountType = prefs.getString('accountType') ?? 'personal';
    });
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(_postsPerPage)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _posts = [];
          _isLoading = false;
          _hasMorePosts = false;
        });
        return;
      }

      final posts = querySnapshot.docs.map((doc) => {
            'id': doc.id,
            ...doc.data(),
          }).toList();

      setState(() {
        _posts = posts;
        _isLoading = false;
        _lastDocument = querySnapshot.docs.last;
        _hasMorePosts = querySnapshot.docs.length == _postsPerPage;
      });
    } catch (e) {
      print('Error loading explore posts: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading posts: $e')),
        );
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMorePosts || _lastDocument == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_postsPerPage)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasMorePosts = false;
        });
        return;
      }

      final newPosts = querySnapshot.docs.map((doc) => {
            'id': doc.id,
            ...doc.data(),
          }).toList();

      setState(() {
        _posts.addAll(newPosts);
        _isLoading = false;
        _lastDocument = querySnapshot.docs.last;
        _hasMorePosts = querySnapshot.docs.length == _postsPerPage;
      });
    } catch (e) {
      print('Error loading more explore posts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshPosts() async {
    _lastDocument = null;
    await _loadPosts();
    return;
  }

  // Helper method to get grid cross axis count based on screen width
  int _getCrossAxisCount(double width) {
    if (width > 1200) return 6;
    if (width > 900) return 5;
    if (width > 600) return 4;
    return 3; // Default for mobile
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width for responsive grid
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(screenWidth);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Explore',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              // Show filter options in a modal bottom sheet
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Filter Posts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Coming soon: Filter by category, date range, and more.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: RefreshIndicator(
            onRefresh: _refreshPosts,
            child: _isLoading && _posts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                    ? _buildEmptyState()
                    : ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(4),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                          itemCount: _posts.length + (_hasMorePosts ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at the end
                            if (index == _posts.length) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue.shade300),
                                ),
                              );
                            }

                            final post = _posts[index];
                            final imageUrl = post['imageUrl'];
                            final username = post['username'] ?? 'Unknown';

                            return GestureDetector(
                              onTap: () {
                                // Navigate to detailed view of the post
                                context.push('/post/${post['id']}');
                              },
                              child: Hero(
                                tag: 'post-${post['id']}',
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
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
                                        post['mediaType'] == 'video'
                                            ? FutureBuilder<String?>(
                                                future: Provider.of<VideoPlayerService>(context, listen: false)
                                                    .generateThumbnail(post['videoUrl'], post['id']),
                                                builder: (context, snapshot) {
                                                  if (snapshot.connectionState == ConnectionState.done && 
                                                      snapshot.data != null) {
                                                    return Stack(
                                                      fit: StackFit.expand,
                                                      children: [
                                                        Image.file(
                                                          File(snapshot.data!),
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) {
                                                            return Container(
                                                              color: Colors.grey.shade900,
                                                              child: const Icon(
                                                                Icons.videocam,
                                                                color: Colors.white54,
                                                                size: 32,
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                        // Video indicator
                                                        Positioned(
                                                          top: 8,
                                                          right: 8,
                                                          child: Container(
                                                            padding: const EdgeInsets.all(4),
                                                            decoration: BoxDecoration(
                                                              color: Colors.black.withOpacity(0.6),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: const Icon(
                                                              Icons.play_arrow,
                                                              color: Colors.white,
                                                              size: 16,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  } else {
                                                    return Container(
                                                      color: Colors.grey.shade900,
                                                      child: const Center(
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              )
                                            : imageUrl != null && imageUrl.isNotEmpty
                                                ? Image.network(
                                                    "${imageUrl}${imageUrl.contains('?') ? '&' : '?'}t=${DateTime.now().millisecondsSinceEpoch}",
                                                    fit: BoxFit.cover,
                                                    loadingBuilder: (context, child, loadingProgress) {
                                                      if (loadingProgress == null) return child;
                                                      return Container(
                                                        color: Colors.grey.shade200,
                                                        child: Center(
                                                          child: CircularProgressIndicator(
                                                            value: loadingProgress.expectedTotalBytes != null
                                                                ? loadingProgress.cumulativeBytesLoaded /
                                                                    loadingProgress.expectedTotalBytes!
                                                                : null,
                                                            strokeWidth: 2,
                                                            color: Colors.blue.shade300,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Container(
                                                        color: Colors.grey.shade200,
                                                        child: const Icon(Icons.broken_image, color: Colors.grey),
                                                      );
                                                    },
                                                  )
                                                : Container(
                                                    color: Colors.grey.shade200,
                                                    child: const Icon(Icons.image, color: Colors.grey),
                                                  ),
                                        // Gradient overlay at bottom for text
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 0,
                                          height: 50,
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                  Colors.black54,
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Username at bottom
                                        Positioned(
                                          left: 8,
                                          right: 8,
                                          bottom: 8,
                                          child: Text(
                                            username,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              shadows: [
                                                Shadow(
                                                  blurRadius: 2,
                                                  color: Colors.black54,
                                                ),
                                              ],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.explore_off_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No posts available to explore',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new content',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _refreshPosts,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
