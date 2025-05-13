// lib/services/shop_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import '../models/cart_model.dart';

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
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('cart')
            .doc(itemId)
            .delete();
      } else {
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('cart')
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
      
      final cartSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('cart')
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
}