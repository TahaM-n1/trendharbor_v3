import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_model.dart';

// Rename from Order to ProductOrder to avoid conflict with Firestore's Order
class ProductOrder {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double subtotal;
  final double shippingCost;
  final double total;
  final Map<String, dynamic> shippingAddress;
  final String deliveryMethod;
  final String status;
  final DateTime createdAt;
  
  ProductOrder({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.shippingCost,
    required this.total,
    required this.shippingAddress,
    required this.deliveryMethod,
    required this.status,
    required this.createdAt,
  });
  
  factory ProductOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    final itemsList = (data['items'] as List<dynamic>)
      .map((item) => OrderItem.fromMap(item))
      .toList();
    
    return ProductOrder(
      id: doc.id,
      userId: data['userId'] ?? '',
      items: itemsList,
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      shippingCost: (data['shippingCost'] ?? 0.0).toDouble(),
      total: (data['total'] ?? 0.0).toDouble(),
      shippingAddress: data['shippingAddress'] as Map<String, dynamic>? ?? {},
      deliveryMethod: data['deliveryMethod'] ?? 'standard',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'shippingCost': shippingCost,
      'total': total,
      'shippingAddress': shippingAddress,
      'deliveryMethod': deliveryMethod,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// Keep OrderItem class unchanged
class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final String imageUrl;
  final String sellerId;
  
  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.imageUrl,
    required this.sellerId,
  });
  
  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0.0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      sellerId: map['sellerId'] ?? '',
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'imageUrl': imageUrl,
      'sellerId': sellerId,
    };
  }
  
  factory OrderItem.fromCartItem(CartItem cartItem) {
    return OrderItem(
      productId: cartItem.productId,
      productName: cartItem.productName,
      quantity: cartItem.quantity,
      price: cartItem.price,
      imageUrl: cartItem.imageUrl,
      sellerId: cartItem.sellerId,
    );
  }
}