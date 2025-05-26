import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../widgets/bottom_navbar.dart';
import '../models/product_model.dart';
import '../services/shop_service.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final ShopService _shopService = ShopService();
  String _accountType = 'personal';
  bool _isLoadingFeatured = true;
  bool _isLoadingProducts = true;
  bool _isAddingToCart = false;
  List<Product> _featuredProducts = [];
  List<Product> _products = [];
  List<String> _categories = [];
  String? _selectedCategory;
  DocumentSnapshot? _lastDocument;
  final int _productsPerPage = 10;
  final ScrollController _scrollController = ScrollController();
  bool _hasMoreProducts = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCategories();
    _loadFeaturedProducts();
    _loadProducts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent * 0.8 &&
          !_isLoadingProducts &&
          _hasMoreProducts) {
        _loadMoreProducts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountType = prefs.getString('accountType');

      if (accountType != null) {
        setState(() {
          _accountType = accountType;
        });
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final userAccountType =
              userDoc.data()?['accountType']?.toString().toLowerCase() ??
                  'personal';

          await prefs.setString('accountType', userAccountType);

          if (mounted) {
            setState(() {
              _accountType = userAccountType;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _shopService.getCategories();

      if (categories.isEmpty) {
        if (mounted) {
          setState(() {
            _categories = [
              'Clothing',
              'Accessories',
              'Electronics',
              'Home',
              'Beauty',
              'Sports',
              'Books'
            ];
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _categories = categories;
          });
        }
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _loadFeaturedProducts() async {
    if (mounted) {
      setState(() {
        _isLoadingFeatured = true;
      });
    }

    try {
      final products = await _shopService.getFeaturedProducts();

      if (mounted) {
        setState(() {
          _featuredProducts = products;
          _isLoadingFeatured = false;
        });
      }
    } catch (e) {
      print('Error loading featured products: $e');
      if (mounted) {
        setState(() {
          _isLoadingFeatured = false;
        });
      }
    }
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _isLoadingProducts = true;
        _lastDocument = null;
      });
    }

    try {
      List<Product> products;

      if (_selectedCategory != null) {
        products = await _shopService.getProductsByCategory(_selectedCategory!);
        _hasMoreProducts = false;
      } else {
        products = await _shopService.getAllProducts(
          limit: _productsPerPage,
        );

        if (products.isNotEmpty) {
          final snapshot = await FirebaseFirestore.instance
              .collection('products')
              .doc(products.last.id)
              .get();

          _lastDocument = snapshot;
          _hasMoreProducts = products.length == _productsPerPage;
        } else {
          _hasMoreProducts = false;
        }
      }

      if (mounted) {
        setState(() {
          _products = products;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      print('Error loading products: $e');
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_selectedCategory != null ||
        !_hasMoreProducts ||
        _isLoadingProducts ||
        _lastDocument == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingProducts = true;
      });
    }

    try {
      final products = await _shopService.getAllProducts(
        limit: _productsPerPage,
        startAfter: _lastDocument,
      );

      if (products.isNotEmpty) {
        final snapshot = await FirebaseFirestore.instance
            .collection('products')
            .doc(products.last.id)
            .get();

        if (mounted) {
          setState(() {
            _products.addAll(products);
            _lastDocument = snapshot;
            _hasMoreProducts = products.length == _productsPerPage;
            _isLoadingProducts = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasMoreProducts = false;
            _isLoadingProducts = false;
          });
        }
      }
    } catch (e) {
      print('Error loading more products: $e');
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  Future<void> _selectCategory(String? category) async {
    if (_selectedCategory == category) {
      setState(() {
        _selectedCategory = null;
      });
    } else {
      setState(() {
        _selectedCategory = category;
      });
    }

    await _loadProducts();
  }

  Future<void> _addToCart(Product product) async {
    if (_isAddingToCart) return;

    setState(() {
      _isAddingToCart = true;
    });

    try {
      final success = await _shopService.addToCart(product);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Added to cart successfully'
                : 'Failed to add to cart'),
            action: success
                ? SnackBarAction(
                    label: 'View Cart',
                    onPressed: () => context.go('/cart'),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  Future<void> _refreshProducts() async {
    await Future.wait([
      _loadFeaturedProducts(),
      _loadProducts(),
    ]);
  }

  void _navigateToProductDetail(String productId) {
    context.push('/product/$productId');
  }

  void _openSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Products'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Enter product name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Search functionality coming soon',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  // Removed the isOrganization check for showing add to cart buttons
  // All account types can now purchase items

  return Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Icon(
            Icons.shopping_bag_outlined, 
            color: Colors.blue.shade700,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text(
            'Shop',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search products',
          onPressed: _openSearchDialog,
        ),
        if (_accountType.toLowerCase() == 'organization')
          IconButton(
            icon: const Icon(Icons.assignment),
            tooltip: 'View Orders',
            onPressed: () => context.push('/seller-orders'),
          ),
        IconButton(
          icon: const Icon(Icons.shopping_cart),
          onPressed: () => context.go('/cart'),
        ),
      ],
    ),
    floatingActionButton: _accountType.toLowerCase() == 'organization'
        ? FloatingActionButton.extended(
            onPressed: () => context.push('/add-product'),
            backgroundColor: Colors.blue.shade700,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Product'),
          )
        : null,
    body: RefreshIndicator(
      onRefresh: _refreshProducts,
      color: Colors.blue.shade700,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ScrollConfiguration(
            // Remove scrollbar with this configuration
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
            ),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Featured Products Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Featured Products',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const Spacer(),
                              if (_isLoadingFeatured)
                                SizedBox(
                                  width: 20, 
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 250,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: _featuredProducts.isEmpty ? Colors.grey.shade50 : Colors.transparent,
                            ),
                            child: _isLoadingFeatured
                                ? const Center(child: SizedBox())
                                : _featuredProducts.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.featured_play_list_outlined,
                                              size: 48,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No featured products available',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ScrollConfiguration(
                                        behavior: ScrollConfiguration.of(context).copyWith(
                                          scrollbars: false,
                                        ),
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _featuredProducts.length,
                                          itemBuilder: (context, index) {
                                            return FeaturedProductCard(
                                              product: _featuredProducts[index],
                                              onTap: () => _navigateToProductDetail(
                                                  _featuredProducts[index].id),
                                              // Enable add to cart for all account types
                                              onAddToCart: () => _addToCart(_featuredProducts[index]),
                                            );
                                          },
                                        ),
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Categories Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 100,
                            child: _categories.isEmpty
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : ScrollConfiguration(
                                    behavior: ScrollConfiguration.of(context).copyWith(
                                      scrollbars: false,
                                    ),
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _categories.length,
                                      itemBuilder: (context, index) {
                                        final category = _categories[index];
                                        final isSelected = _selectedCategory == category;

                                        return CategoryItem(
                                          icon: _getCategoryIcon(category),
                                          label: category,
                                          color: _getCategoryColor(category, index),
                                          isSelected: isSelected,
                                          onTap: () => _selectCategory(category),
                                        );
                                      },
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Products Header Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _selectedCategory != null
                                    ? _selectedCategory!
                                    : 'All Products',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const Spacer(),
                              if (_selectedCategory != null)
                                TextButton.icon(
                                  onPressed: () => _selectCategory(null),
                                  icon: Icon(Icons.clear, size: 16, color: Colors.blue.shade700),
                                  label: Text(
                                    'Clear Filter',
                                    style: TextStyle(color: Colors.blue.shade700),
                                  ),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.blue.shade50,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              if (_isLoadingProducts && _products.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Products Grid Section - Modified to show add to cart for all users
                _isLoadingProducts && _products.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                          ),
                        ),
                      )
                    : _products.isEmpty
                        ? SliverFillRemaining(
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.inventory_2_outlined,
                                        size: 64,
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No products available',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 40),
                                      child: Text(
                                        _selectedCategory != null
                                            ? 'Try selecting a different category'
                                            : 'Check back later for new products',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    if (_selectedCategory != null)
                                      ElevatedButton.icon(
                                        onPressed: () => _selectCategory(null),
                                        icon: const Icon(Icons.category_outlined),
                                        label: const Text('View All Products'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade700,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            sliver: SliverLayoutBuilder(
                              builder: (BuildContext context, constraints) {
                                double itemWidth = 200;
                                int crossAxisCount =
                                    (constraints.crossAxisExtent / itemWidth)
                                        .floor();
                                crossAxisCount = crossAxisCount < 1
                                    ? 1
                                    : (crossAxisCount > 6 ? 6 : crossAxisCount);

                                return SliverGrid(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 0.65,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      return ProductCard(
                                        product: _products[index],
                                        onTap: () => _navigateToProductDetail(
                                            _products[index].id),
                                        // Enable add to cart for all account types
                                        onAddToCart: () => _addToCart(_products[index]),
                                      );
                                    },
                                    childCount: _products.length,
                                  ),
                                );
                              },
                            ),
                          ),
                
                // Loading indicator at bottom
                if (_isLoadingProducts && _products.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: SizedBox(
                          width: 24, 
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
                
                // Bottom padding
                SliverToBoxAdapter(
                  child: SizedBox(height: 40),
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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'clothing':
        return Icons.checkroom;
      case 'accessories':
        return Icons.watch;
      case 'electronics':
        return Icons.devices;
      case 'home':
        return Icons.home;
      case 'beauty':
        return Icons.spa;
      case 'sports':
        return Icons.fitness_center;
      case 'books':
        return Icons.book;
      case 'toys':
        return Icons.toys;
      case 'food':
        return Icons.fastfood;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category, int index) {
    final colors = [
      Colors.blue.shade100,
      Colors.green.shade100,
      Colors.orange.shade100,
      Colors.purple.shade100,
      Colors.red.shade100,
      Colors.teal.shade100,
      Colors.pink.shade100,
      Colors.amber.shade100,
      Colors.indigo.shade100,
    ];

    switch (category.toLowerCase()) {
      case 'clothing':
        return Colors.blue.shade100;
      case 'accessories':
        return Colors.purple.shade100;
      case 'electronics':
        return Colors.teal.shade100;
      case 'home':
        return Colors.orange.shade100;
      case 'beauty':
        return Colors.pink.shade100;
      case 'sports':
        return Colors.green.shade100;
      case 'books':
        return Colors.indigo.shade100;
      case 'toys':
        return Colors.amber.shade100;
      case 'food':
        return Colors.red.shade100;
      default:
        return colors[index % colors.length];
    }
  }
}

// Updated FeaturedProductCard
class FeaturedProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;

  const FeaturedProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 250, // Fixed height to prevent overflow
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image section with fixed height
                SizedBox(
                  height: 130, // Fixed height for image
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 130,
                        width: double.infinity,
                        child: product.imageUrls.isNotEmpty
                            ? Image.network(
                                product.imageUrls[0],
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey.shade100,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade100,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.broken_image,
                                        size: 50, color: Colors.grey),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey.shade100,
                                alignment: Alignment.center,
                                child: const Icon(Icons.image_not_supported,
                                    size: 50, color: Colors.grey),
                              ),
                      ),
                      if (product.isFeatured)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Featured',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (product.stock <= 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Out of Stock',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Content section - fixed height calculation 
                // Total height (250) - Image height (130) = 120px for content
                SizedBox(
                  height: 120,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title with constrained height
                        SizedBox(
                          height: 20,
                          child: Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        // Category and rating row
                        SizedBox(
                          height: 20,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  product.category,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (product.rating > 0) ...[
                                Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                                const SizedBox(width: 2),
                                Text(
                                  product.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        // Price with fixed height
                        SizedBox(
                          height: 20,
                          child: Text(
                            '\$${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        
                        // Spacing and button with fixed height
                        const Spacer(flex: 1),
                        if (onAddToCart != null)
                          SizedBox(
                            width: double.infinity,
                            height: 32, // Slightly reduced height
                            child: ElevatedButton(
                              onPressed: product.stock > 0 ? onAddToCart : null,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.blue.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.zero,
                                elevation: 0,
                              ),
                              child: Text(
                                product.stock > 0 ? 'Add to Cart' : 'Out of Stock',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Updated ProductCard
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image section with badges
                Stack(
                  children: [
                    SizedBox(
                      height: 180, // Fixed height
                      width: double.infinity,
                      child: product.imageUrls.isNotEmpty
                          ? Image.network(
                              product.imageUrls[0],
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey.shade100,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade100,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image,
                                      size: 40, color: Colors.grey),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade100,
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_not_supported,
                                  size: 40, color: Colors.grey),
                            ),
                    ),
                    if (product.isFeatured)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Featured',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (product.stock <= 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Out of Stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                
                // Product info section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product.category,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (product.rating > 0) ...[
                              Icon(Icons.star,
                                  size: 14, color: Colors.amber.shade600),
                              const SizedBox(width: 2),
                              Text(
                                product.rating.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Price row
                        Row(
                          children: [
                            Text(
                              '\$${product.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: product.stock > 0 ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product.stock > 0 ? 'In Stock' : 'Out of Stock',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: product.stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Add to cart button
                        if (onAddToCart != null)
                          SizedBox(
                            width: double.infinity,
                            height: 36,
                            child: ElevatedButton(
                              onPressed: product.stock > 0 ? onAddToCart : null,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.blue.shade700,
                                padding: const EdgeInsets.symmetric(vertical: 0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.shopping_cart_outlined, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    product.stock > 0 ? 'Add to Cart' : 'Out of Stock',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Updated CategoryItem
class CategoryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryItem({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.shade50
            : color,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: Colors.blue.shade700, width: 2)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.blue.shade100.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 30,
                color: isSelected
                    ? Colors.blue.shade700
                    : Colors.grey.shade700,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: isSelected
                      ? Colors.blue.shade700
                      : Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}