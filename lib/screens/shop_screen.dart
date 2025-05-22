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

  @override
  Widget build(BuildContext context) {
    final isOrganization = _accountType.toLowerCase() == 'organization';

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Shop', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search feature coming soon')),
              );
            },
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
      floatingActionButton: isOrganization
          ? FloatingActionButton(
              onPressed: () => context.push('/add-product'),
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refreshProducts,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Featured Products',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Fixed height to prevent overflow
                    SizedBox(
                      height: 270, // Increased to 270 to avoid overflow
                      child: _isLoadingFeatured
                          ? const Center(child: CircularProgressIndicator())
                          : _featuredProducts.isEmpty
                              ? const Center(
                                  child: Text('No featured products available'))
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _featuredProducts.length,
                                  itemBuilder: (context, index) {
                                    return FeaturedProductCard(
                                      product: _featuredProducts[index],
                                      onTap: () => _navigateToProductDetail(
                                          _featuredProducts[index].id),
                                      onAddToCart: isOrganization
                                          ? null
                                          : () => _addToCart(
                                              _featuredProducts[index]),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: _categories.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final category = _categories[index];
                                final isSelected =
                                    _selectedCategory == category;

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
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _selectedCategory != null
                              ? _selectedCategory!
                              : 'All Products',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedCategory != null)
                          TextButton(
                            onPressed: () => _selectCategory(null),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            _isLoadingProducts && _products.isEmpty
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _products.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(child: Text('No products available')),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        sliver: SliverLayoutBuilder(
                          builder: (BuildContext context, constraints) {
                            double itemWidth = 180;
                            int crossAxisCount =
                                (constraints.crossAxisExtent / itemWidth)
                                    .floor();
                            crossAxisCount = crossAxisCount < 1
                                ? 1
                                : (crossAxisCount > 4 ? 4 : crossAxisCount);

                            return SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                // Adjusted child aspect ratio to fix overflow
                                childAspectRatio:
                                    0.62, // Further reduced to avoid overflow
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  return ProductCard(
                                    product: _products[index],
                                    onTap: () => _navigateToProductDetail(
                                        _products[index].id),
                                    onAddToCart: isOrganization
                                        ? null
                                        : () => _addToCart(_products[index]),
                                  );
                                },
                                childCount: _products.length,
                              ),
                            );
                          },
                        ),
                      ),
            if (_isLoadingProducts && _products.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            // Added extra padding at the bottom to prevent any potential overflow with bottom nav bar
            SliverToBoxAdapter(
              child: SizedBox(height: 30), // Increased from 20 to 30
            ),
          ],
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
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: product.imageUrls.isNotEmpty
                          ? Image.network(
                              product.imageUrls[0],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image,
                                      size: 50, color: Colors.grey),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_not_supported,
                                  size: 50, color: Colors.grey),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(
                          10), // Reduced padding from 12 to 10
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const Spacer(),
                              if (product.rating > 0) ...[
                                Icon(Icons.star,
                                    size: 16, color: Colors.amber.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  product.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ]
                            ],
                          ),
                          if (onAddToCart != null) ...[
                            const SizedBox(height: 6), // Reduced from 8 to 6
                            SizedBox(
                              width: double.infinity,
                              height: 30, // Fixed height ensures consistency
                              child: ElevatedButton.icon(
                                onPressed:
                                    product.stock > 0 ? onAddToCart : null,
                                icon: const Icon(Icons.shopping_cart,
                                    size: 14), // Smaller icon
                                label: Text(
                                  product.stock > 0
                                      ? 'Add to Cart'
                                      : 'Out of Stock',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 0),
                                  minimumSize: const Size(double.infinity, 30),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (product.isFeatured)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:
              MainAxisSize.min, // Ensures column takes minimum space needed
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: product.imageUrls.isNotEmpty
                  ? Image.network(
                      product.imageUrls[0],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image,
                              size: 40, color: Colors.grey),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported,
                          size: 40, color: Colors.grey),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(
                  6.0), // Further reduced padding from 8 to 6
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2), // Reduced spacing
                  Row(
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
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
                  const SizedBox(height: 2), // Reduced spacing
                  Text(
                    product.stock > 0 ? 'In Stock' : 'Out of Stock',
                    style: TextStyle(
                      fontSize: 12,
                      color: product.stock > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(), // Uses remaining space
            if (onAddToCart != null)
              InkWell(
                onTap: product.stock > 0 ? onAddToCart : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  color: product.stock > 0
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Colors.grey.shade200,
                  child: Center(
                    child: Text(
                      product.stock > 0 ? 'Add to Cart' : 'Out of Stock',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: product.stock > 0
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
            ? Theme.of(context).primaryColor.withOpacity(0.2)
            : color,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: Theme.of(context).primaryColor, width: 2)
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 30,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : color.withGreen(80),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
