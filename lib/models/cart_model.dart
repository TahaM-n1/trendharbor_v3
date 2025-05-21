// lib/models/cart_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem {
  final String id;
  final String productId;
  final String productName;
  final double price;
  final String imageUrl;
  final int quantity;
  final String sellerId;
  
  CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.price,
    required this.imageUrl,
    required this.quantity,
    required this.sellerId,
  });
  
  factory CartItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CartItem(
      id: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
      quantity: data['quantity'] ?? 1,
      sellerId: data['sellerId'] ?? '',
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'sellerId': sellerId,
      'addedAt': FieldValue.serverTimestamp(),
    };
  }
  
  double get totalPrice => price * quantity;
  
  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      productId: productId,
      productName: productName,
      price: price,
      imageUrl: imageUrl,
      quantity: quantity ?? this.quantity,
      sellerId: sellerId,
    );
  }
}