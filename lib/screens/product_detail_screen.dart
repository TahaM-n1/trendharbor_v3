// lib/screens/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../services/shop_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ShopService _shopService = ShopService();
  bool _isLoading = true;
  Product? _product;
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isSubmittingComment = false;
  bool _isAddingToCart = false;
  String _accountType = 'personal'; // Default value
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load product details
      final product = await _shopService.getProductDetails(widget.productId);
      
      if (product == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product not found')),
          );
          context.go('/shop');
        }
        return;
      }
      
      // Load product comments
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
          
      final comments = commentsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'userId': data['userId'] ?? '',
          'username': data['username'] ?? 'Anonymous',
          'userProfileImage': data['userProfileImage'] ?? '',
          'comment': data['comment'] ?? '',
          'timestamp': data['timestamp'] ?? Timestamp.now(),
        };
      }).toList();
      
      // Get user account type
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (userDoc.exists) {
          _accountType = userDoc.data()?['accountType']?.toString().toLowerCase() ?? 'personal';
        }
      }
      
      if (mounted) {
        setState(() {
          _product = product;
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading product details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading product details: $e')),
        );
      }
    }
  }
  
  Future<void> _addToCart() async {
    if (_product == null) return;
    
    setState(() {
      _isAddingToCart = true;
    });
    
    try {
      final success = await _shopService.addToCart(_product!);
      
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Added to cart successfully'),
              action: SnackBarAction(
                label: 'View Cart',
                onPressed: () => context.go('/cart'),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add item to cart')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding to cart: $e')),
        );
      }
    }
  }
  
  Future<void> _addComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty || _product == null) return;
    
    setState(() {
      _isSubmittingComment = true;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Get user profile data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }
      
      final userData = userDoc.data()!;
      
      // Add comment to Firestore
      final commentRef = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .collection('comments')
          .add({
            'userId': user.uid,
            'username': userData['username'] ?? 'Anonymous',
            'userProfileImage': userData['profileImageUrl'] ?? '',
            'comment': comment,
            'timestamp': FieldValue.serverTimestamp(),
          });
          
      // Update UI optimistically
      if (mounted) {
        setState(() {
          _comments.insert(0, {
            'id': commentRef.id,
            'userId': user.uid,
            'username': userData['username'] ?? 'Anonymous',
            'userProfileImage': userData['profileImageUrl'] ?? '',
            'comment': comment,
            'timestamp': Timestamp.now(),
          });
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
  
  void _shareProduct() {
    // Will implement sharing via DM in future
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing via DMs coming soon')),
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
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final product = _product!;
    final isOrganizationAccount = _accountType.toLowerCase() == 'organization';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareProduct,
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => context.go('/cart'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Images
                  SizedBox(
                    height: 300,
                    child: PageView.builder(
                      itemCount: product.imageUrls.isEmpty ? 1 : product.imageUrls.length,
                      itemBuilder: (context, index) {
                        if (product.imageUrls.isEmpty) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                            ),
                          );
                        }
                        
                        return Image.network(
                          product.imageUrls[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  
                  // Product Info
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product.category,
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (product.rating > 0)
                              Row(
                                children: [
                                  Icon(Icons.star, size: 18, color: Colors.amber.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${product.rating.toStringAsFixed(1)} (${product.reviewCount})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          product.description,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.store, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Sold by: ${product.sellerName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              product.stock > 0 ? Icons.check_circle : Icons.cancel,
                              size: 16,
                              color: product.stock > 0 ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              product.stock > 0 ? 'In Stock' : 'Out of Stock',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: product.stock > 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        
                        // Comments section
                        const Text(
                          'Customer Reviews',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        if (_comments.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.0),
                              child: Text('No reviews yet. Be the first to review!'),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              final comment = _comments[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundImage: comment['userProfileImage'] != null && 
                                                            comment['userProfileImage'].isNotEmpty
                                                ? NetworkImage(comment['userProfileImage'])
                                                : null,
                                            child: comment['userProfileImage'] == null || 
                                                   comment['userProfileImage'].isEmpty
                                                ? Text(comment['username'][0].toUpperCase())
                                                : null,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            comment['username'] ?? 'Anonymous',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            _formatTimestamp(comment['timestamp']),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(comment['comment']),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Don't show Add to Cart for organizations
                  if (!isOrganizationAccount)
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: product.stock > 0 && !_isAddingToCart ? _addToCart : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isAddingToCart
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Add to Cart',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Comment input field (don't show for organizations)
          if (!isOrganizationAccount)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Add a review...',
                          border: InputBorder.none,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    IconButton(
                      icon: _isSubmittingComment
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      onPressed: _isSubmittingComment ? null : _addComment,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}