// lib/services/shop_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import '../models/cart_model.dart';
import '../models/product_order_model.dart' as order_model;

class ShopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Get all product categories
  Future<List<String>> getCategories() async {
    try {
      final categoriesSnapshot = await _firestore.collection('product_categories').get();
      
      return categoriesSnapshot.docs
          .map((doc) => doc['name'] as String)
          .toList();
    } catch (e) {
      print('Error loading categories: $e');
      return [];
    }
  }
  
  // Get featured products
  Future<List<Product>> getFeaturedProducts() async {
    try {
      final productsSnapshot = await _firestore
          .collection('products')
          .where('isFeatured', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
          
      return productsSnapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error loading featured products: $e');
      return [];
    }
  }
  
  // Get products by category
  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      final productsSnapshot = await _firestore
          .collection('products')
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .get();
          
      return productsSnapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error loading products by category: $e');
      return [];
    }
  }
  
  // Get all products
  Future<List<Product>> getAllProducts({int limit = 20, DocumentSnapshot? startAfter}) async {
    try {
      Query query = _firestore
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(limit);
          
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      final productsSnapshot = await query.get();
          
      return productsSnapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error loading all products: $e');
      return [];
    }
  }
  
  // Get product details
  Future<Product?> getProductDetails(String productId) async {
    try {
      final productDoc = await _firestore
          .collection('products')
          .doc(productId)
          .get();
          
      if (!productDoc.exists) {
        return null;
      }
      
      return Product.fromFirestore(productDoc);
    } catch (e) {
      print('Error loading product details: $e');
      return null;
    }
  }
  
  // Add product to cart
  Future<bool> addToCart(Product product, {int quantity = 1}) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      await _firestore.collection('cartItems').add({
        'userId': currentUserId,
        'productId': product.id,
        'productName': product.name,
        'sellerName': product.sellerName,
        'price': product.price,
        'quantity': quantity,
        'imageUrl': product.imageUrls.isNotEmpty ? product.imageUrls[0] : '',
        'sellerId': product.sellerId,
        'addedAt': Timestamp.now(),
      });
      
      return true;
    } catch (e) {
      print('Error adding to cart: $e');
      return false;
    }
  }
  
  // Get cart items
  Future<List<CartItem>> getCartItems() async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final snapshot = await _firestore
          .collection('cartItems')
          .where('userId', isEqualTo: currentUserId)
          .get();
          
      return snapshot.docs.map((doc) {
        return CartItem.fromFirestore(doc);
      }).toList();
    } catch (e) {
      print('Error getting cart items: $e');
      return [];
    }
  }
  
  // Update cart item quantity
  Future<bool> updateCartItemQuantity(String itemId, int quantity) async {
    try {
      if (currentUserId == null) {
        return false;
      }
      
      if (quantity <= 0) {
        // Delete item if quantity is 0 or less
        await _firestore
            .collection('cartItems')
            .doc(itemId)
            .delete();
      } else {
        // Update quantity if greater than 0
        await _firestore
            .collection('cartItems')
            .doc(itemId)
            .update({'quantity': quantity});
      }
      
      return true;
    } catch (e) {
      print('Error updating cart item: $e');
      return false;
    }
  }
  
  // Clear cart
  Future<bool> clearCart() async {
    try {
      if (currentUserId == null) {
        return false;
      }
      
      // This was incorrectly using users/[id]/cart instead of cartItems
      final cartSnapshot = await _firestore
          .collection('cartItems')
          .where('userId', isEqualTo: currentUserId)
          .get();
          
      final batch = _firestore.batch();
      for (var doc in cartSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      print('Error clearing cart: $e');
      return false;
    }
  }
  
  // Check if user can add products (only organizations)
  Future<bool> canAddProducts() async {
    try {
      if (currentUserId == null) {
        return false;
      }
      
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
          
      if (!userDoc.exists) {
        return false;
      }
      
      final accountType = userDoc.data()?['accountType']?.toString().toLowerCase();
      return accountType == 'organization';
    } catch (e) {
      print('Error checking seller permissions: $e');
      return false;
    }
  }
  
  // Add product (only for organizations)
  Future<String?> addProduct(Product product) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // Check if user is an organization
      final canSell = await canAddProducts();
      if (!canSell) {
        throw Exception('Only organizations can add products');
      }
      
      final productData = product.toMap();
      
      final docRef = await _firestore
          .collection('products')
          .add(productData);
          
      return docRef.id;
    } catch (e) {
      print('Error adding product: $e');
      return null;
    }
  }
  
  // Place an order
  Future<String?> placeOrder(
    List<CartItem> cartItems,
    double subtotal,
    Map<String, dynamic> shippingAddress,
    String deliveryMethod,
  ) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // Calculate shipping cost and total
      final shippingCost = deliveryMethod == 'express' ? 9.99 : 4.99;
      final total = subtotal + shippingCost;
      
      // Convert cart items to order items
      final orderItems = cartItems.map((item) => order_model.OrderItem.fromCartItem(item)).toList();
      
      // Create a new order document
      final orderRef = await _firestore.collection('orders').add({
        'userId': currentUserId,
        'items': orderItems.map((item) => item.toMap()).toList(),
        'subtotal': subtotal,
        'shippingCost': shippingCost,
        'total': total,
        'shippingAddress': shippingAddress,
        'deliveryMethod': deliveryMethod,
        'status': 'processing', // Initial status
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Update inventory for each product
      final batch = _firestore.batch();
      
      for (final item in cartItems) {
        final productRef = _firestore.collection('products').doc(item.productId);
        final productDoc = await productRef.get();
        
        if (productDoc.exists) {
          final currentStock = productDoc.data()?['stock'] ?? 0;
          batch.update(productRef, {
            'stock': currentStock - item.quantity,
          });
        }
      }
      
      // Clear the cart after placing order
      final cartSnapshot = await _firestore
        .collection('cartItems')
        .where('userId', isEqualTo: currentUserId)
        .get();
        
      for (final doc in cartSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Commit all updates
      await batch.commit();
      
      return orderRef.id;
      
    } catch (e) {
      print('Error placing order: $e');
      return null;
    }
  }
  
  // Get user's orders
  Future<List<order_model.ProductOrder>> getUserOrders() async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      final ordersSnapshot = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .get();
        
      return ordersSnapshot.docs
        .map((doc) => order_model.ProductOrder.fromFirestore(doc))
        .toList();
        
    } catch (e) {
      print('Error getting user orders: $e');
      return [];
    }
  }
  
  // Get orders for seller (organization account only)
  Future<List<order_model.ProductOrder>> getSellerOrders() async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // First check if user is an organization
      final userDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .get();
        
      if (!userDoc.exists || userDoc.data()?['accountType']?.toString().toLowerCase() != 'organization') {
        throw Exception('Only organizations can view seller orders');
      }
      
      final ordersSnapshot = await _firestore
        .collection('orders')
        .get();
        
      // Filter orders containing products sold by this seller
      final orders = <order_model.ProductOrder>[];
      for (final doc in ordersSnapshot.docs) {
        final order = order_model.ProductOrder.fromFirestore(doc);
        final hasSellersItems = order.items.any((item) => item.sellerId == currentUserId);
        
        if (hasSellersItems) {
          orders.add(order);
        }
      }
      
      return orders;
      
    } catch (e) {
      print('Error getting seller orders: $e');
      return [];
    }
  }
  
  // Update order status (organization/seller only)
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // First check if user is an organization
      final userDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .get();
        
      if (!userDoc.exists || userDoc.data()?['accountType']?.toString().toLowerCase() != 'organization') {
        throw Exception('Only organizations can update order status');
      }
      
      await _firestore
        .collection('orders')
        .doc(orderId)
        .update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
      return true;
      
    } catch (e) {
      print('Error updating order status: $e');
      return false;
    }
  }

  // Remove cart item
  Future<bool> removeCartItem(String itemId) async {
    try {
      if (currentUserId == null) {
        return false;
      }
      
      await _firestore
          .collection('cartItems')
          .doc(itemId)
          .delete();
      
      return true;
    } catch (e) {
      print('Error removing cart item: $e');
      return false;
    }
  }
}