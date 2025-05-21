import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../widgets/video_post_widget.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  
  const PostDetailScreen({
    super.key,
    required this.postId,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _postData;
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLiked = false;
  bool _isSubmittingComment = false;
  bool _showLikeOverlay = false;
  
  @override
  void initState() {
    super.initState();
    _loadPostData();
  }
  
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPostData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get post data
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();
      
      if (!postDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post not found')),
          );
          context.pop();
        }
        return;
      }
      
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Get like status
      bool isLiked = false;
      if (currentUser != null) {
        final likeDoc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('likes')
            .doc(currentUser.uid)
            .get();
            
        isLiked = likeDoc.exists;
      }
      
      // Get comments
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .limit(50)
          .get();
      
      final comments = commentsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      if (mounted) {
        setState(() {
          _postData = {
            'id': postDoc.id,
            ...postDoc.data()!,
          };
          _isLiked = isLiked;
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading post data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading post: $e')),
        );
      }
    }
  }
  
  Future<void> _toggleLike() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _postData == null) return;
    
    final likeRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('likes')
        .doc(currentUser.uid);
    
    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId);
        
    try {
      // Toggle like status
      if (_isLiked) {
        // Unlike
        await likeRef.delete();
        await postRef.update({
          'likes': FieldValue.increment(-1),
        });
      } else {
        // Like
        await likeRef.set({
          'userId': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        await postRef.update({
          'likes': FieldValue.increment(1),
        });
      }
      
      // Update state
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          if (_isLiked) {
            _postData!['likes'] = (_postData!['likes'] ?? 0) + 1;
          } else {
            _postData!['likes'] = (_postData!['likes'] ?? 0) - 1;
          }
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating like: $e')),
        );
      }
    }
  }
  
  Future<void> _addComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _postData == null) return;
    
    setState(() {
      _isSubmittingComment = true;
    });
    
    try {
      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
          
      final userData = userDoc.data();
      
      if (userData == null) {
        throw Exception('User data not found');
      }
      
      // Create comment
      final commentRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments');
          
      final commentDoc = await commentRef.add({
        'userId': currentUser.uid,
        'username': userData['username'] ?? 'Unknown User',
        'userProfileImage': userData['profileImageUrl'] ?? '',
        'text': comment,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Update comment count
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({
            'comments': FieldValue.increment(1),
          });
          
      // Add comment to local list
      if (mounted) {
        setState(() {
          _comments.add({
            'id': commentDoc.id,
            'userId': currentUser.uid,
            'username': userData['username'] ?? 'Unknown User',
            'userProfileImage': userData['profileImageUrl'] ?? '',
            'text': comment,
            'timestamp': Timestamp.now(),
          });
          _postData!['comments'] = (_postData!['comments'] ?? 0) + 1;
          _commentController.clear();
          _isSubmittingComment = false;
        });
      }
    } catch (e) {
      print('Error adding comment: $e');
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')),
        );
      }
    }
  }
  
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now();
    final dateTime = timestamp.toDate();
    
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat.yMMMd().format(dateTime);
    }
  }
  
  void _showLikeAnimation() {
    setState(() {
      _showLikeOverlay = true;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showLikeOverlay = false;
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.blue.shade700)),
      );
    }
    
    final post = _postData!;
    final timestamp = post['timestamp'] as Timestamp?;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Post', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          if (FirebaseAuth.instance.currentUser?.uid == post['userId'])
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteDialog(),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // Centering container for all content
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 700, // Same max width as the image
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Post header with enhanced styling
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
                                    backgroundImage: post['userProfileImage'] != null && post['userProfileImage'].isNotEmpty
                                        ? NetworkImage(post['userProfileImage'])
                                        : null,
                                    child: post['userProfileImage'] == null || post['userProfileImage'].isEmpty
                                        ? Text(post['username'][0].toUpperCase())
                                        : null,
                                    backgroundColor: Colors.blue.shade100,
                                  ),
                                ),
                              ),
                              title: Text(
                                post['username'] ?? 'Unknown User',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: timestamp != null
                                  ? Text(
                                      _formatTimestamp(timestamp),
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        
                        // Image - with double tap functionality
                        GestureDetector(
                          onDoubleTap: () {
                            // Show heart animation and toggle like
                            _showLikeAnimation();
                            if (!_isLiked) {
                              _toggleLike();
                            }
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Check if it's a video post
                              post['mediaType'] == 'video'
                                  ? VideoPostWidget(
                                      postId: post['id'],
                                      videoUrl: post['videoUrl'],
                                      thumbnailUrl: post['thumbnailUrl'] ?? post['videoUrl'],
                                    )
                                  : Hero(
                                      tag: 'post-${post['id']}',
                                      child: AspectRatio(
                                        aspectRatio: 1.0, // Square aspect ratio
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100], // Lighter background while loading
                                          ),
                                          child: Image.network(
                                            post['imageUrl'],
                                            fit: BoxFit.contain, // Contain to avoid stretching
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
                                              print("Error loading post image: $error");
                                              return Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.broken_image,
                                                      size: 50,
                                                      color: Colors.grey.shade400,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Image not available',
                                                      style: TextStyle(color: Colors.grey.shade600),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                              // Like animation overlay
                              AnimatedOpacity(
                                opacity: _showLikeOverlay ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: AnimatedScale(
                                  scale: _showLikeOverlay ? 1.2 : 0.8,
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
                        
                        // Actions row with enhanced styling
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
                                  _isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: _isLiked ? Colors.red.shade500 : Colors.grey.shade700,
                                  size: 28,
                                ),
                                onPressed: _toggleLike,
                                splashColor: Colors.red.shade100,
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.comment_outlined,
                                  color: Colors.grey.shade700,
                                  size: 26,
                                ),
                                onPressed: () {
                                  // Focus on comment field
                                  FocusScope.of(context).requestFocus(FocusNode());
                                  Future.delayed(const Duration(milliseconds: 100), () {
                                    FocusScope.of(context).requestFocus();
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.send,
                                  color: Colors.grey.shade700,
                                  size: 24,
                                ),
                                onPressed: () {
                                  _sharePost();
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
                                  // Save post
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Save feature coming soon')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        // Likes count with enhanced styling
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
                                '${post['likes'] ?? 0} likes',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Caption - REDUCED SIZE as requested
                        if (post['caption'] != null && post['caption'].isNotEmpty)
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
                                  fontSize: 17, // REDUCED from default ~14
                                  height: 1.3, // Better line height for readability
                                ),
                                children: [
                                  TextSpan(
                                    text: post['username'] ?? 'Unknown User',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13, // REDUCED
                                    ),
                                  ),
                                  const TextSpan(text: ' '),
                                  TextSpan(
                                    text: post['caption'],
                                    style: TextStyle(
                                      height: 1.4,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        
                        // Comments section header - modernized
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade200,
                                offset: const Offset(0, -2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Comments',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${_comments.length}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (_comments.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () {
                                    // Future implementation: show all comments in full screen
                                  },
                                  icon: Icon(Icons.sort, size: 16, color: Colors.blue.shade700),
                                  label: Text(
                                    'Latest',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    backgroundColor: Colors.blue.shade50,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Comments list - modernized
                        if (_comments.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No comments yet',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Be the first to share your thoughts',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _comments.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                indent: 68,
                                endIndent: 16,
                                color: Colors.grey.shade200,
                              ),
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                final commentTimestamp = comment['timestamp'] as Timestamp?;
                                
                                return Container(
                                  decoration: BoxDecoration(
                                    color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                                    borderRadius: index == _comments.length - 1
                                        ? const BorderRadius.only(
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          )
                                        : null,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Profile picture with gradient border
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
                                              // Username and timestamp row
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
                                                    _formatTimestamp(commentTimestamp),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              // Comment text in a subtle container
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
                                              // Action buttons
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
                          ),

                        // Extra space at bottom
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Enhanced comment box
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 700,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue.shade50,
                      backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null
                          ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                          : null,
                      child: FirebaseAuth.instance.currentUser?.photoURL == null
                          ? Text(
                              FirebaseAuth.instance.currentUser?.displayName?.isNotEmpty == true
                                  ? FirebaseAuth.instance.currentUser!.displayName![0].toUpperCase()
                                  : 'U',
                              style: TextStyle(color: Colors.blue.shade800),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                            border: InputBorder.none,
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _isSubmittingComment ? null : _addComment,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _commentController.text.trim().isNotEmpty
                                ? Colors.blue.shade700
                                : Colors.grey.shade300,
                            shape: BoxShape.circle,
                          ),
                          child: _isSubmittingComment
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(
                                  Icons.send,
                                  color: _commentController.text.trim().isNotEmpty
                                      ? Colors.white
                                      : Colors.grey.shade500,
                                  size: 22,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _deletePost() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Deleting post...'),
            ],
          ),
        ),
      );
      
      final String imageUrl = _postData!['imageUrl'];
      
      // Delete post document
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .delete();
          
      // Delete image from storage if it exists
      if (imageUrl.isNotEmpty && imageUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final encodedPath = imageUrl.split('/o/').last.split('?').first;
          final decodedPath = Uri.decodeComponent(encodedPath);
          
          await FirebaseStorage.instance.ref(decodedPath).delete();
          print('Deleted image: $decodedPath');
        } catch (e) {
          print('Error deleting image: $e');
          // Continue even if image deletion fails
        }
      }
      
      // Navigate back twice (close loading dialog and post screen)
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        context.go('/profile'); // Return to profile
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sharePost() {
    if (_postData == null) return;
    _sharePostInDM(_postData!);
  }

  void _sharePostInDM(Map<String, dynamic> postData) {
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
              content: SizedBox(
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
                                      await _sendPostToUser(user['id'], postData);
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

  Future<void> _sendPostToUser(String recipientId, Map<String, dynamic> postData) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
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
                Text('Sending post...'),
              ],
            ),
          );
        },
      );

      // Check if chat already exists between these users
      final chatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();
      
      String chatId = '';
      
      for (final doc in chatQuery.docs) {
        final List<dynamic> participants = doc['participants'];
        if (participants.contains(recipientId)) {
          chatId = doc.id;
          break;
        }
      }
      
      // If no chat exists, create a new one
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
        // Update the existing chat's last message
        await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
          'lastMessage': {
            'text': 'Shared a post with you',
            'timestamp': FieldValue.serverTimestamp(),
            'senderId': currentUser.uid,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Add message with shared post
      await FirebaseFirestore.instance.collection('messages').add({
        'chatId': chatId,
        'senderId': currentUser.uid,
        'text': 'Shared a post with you',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'post_share',
        'read': false,
        'sharedPost': {
          'postId': postData['id'],
          'imageUrl': postData['imageUrl'],
          'username': postData['username'],
          'caption': postData['caption'] ?? '',
        },
      });
      
      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error sharing post: $e');
    }
  }
}