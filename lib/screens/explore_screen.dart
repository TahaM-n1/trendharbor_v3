// lib/screens/explore_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        child: _isLoading && _posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _posts.isEmpty 
                ? const Center(child: Text('No posts available'))
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(2),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: _posts.length + (_hasMorePosts ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show loading indicator at the end
                      if (index == _posts.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      final post = _posts[index];
                      final imageUrl = post['imageUrl'];
                      
                      return GestureDetector(
                        onTap: () {
                          // Navigate to detailed view of the post
                          context.push('/post/${post['id']}');
                        },
                        child: Hero(
                          tag: 'post-${post['id']}',
                          child: Container(
                            color: Colors.grey.shade200,
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? Image.network(
                                    "${imageUrl}${imageUrl.contains('?') ? '&' : '?'}t=${DateTime.now().millisecondsSinceEpoch}",
                                    fit: BoxFit.cover,
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
                                      return const Icon(Icons.broken_image);
                                    },
                                  )
                                : const Center(child: Icon(Icons.image)),
                          ),
                        ),
                      );
                    },
                  ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}
