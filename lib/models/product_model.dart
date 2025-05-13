// lib/models/product_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final double price;
  final String description;
  final List<String> imageUrls;
  final String category;
  final String sellerId;
  final String sellerName; // New field for seller name
  final bool isFeatured;
  final int stock;
  final double rating;
  final int reviewCount; // New field for review count
  final Timestamp createdAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrls,
    required this.category,
    required this.sellerId,
    required this.sellerName, // Added parameter
    required this.isFeatured,
    required this.stock,
    required this.rating,
    required this.reviewCount, // Added parameter
    required this.createdAt,
  });

  // Factory constructor to create a Product from a Firestore document
  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      category: data['category'] ?? '',
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? 'Unknown Seller', // Added with default
      isFeatured: data['isFeatured'] ?? false,
      stock: data['stock'] ?? 0,
      rating: (data['rating'] ?? 0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0, // Added with default
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'description': description,
      'imageUrls': imageUrls,
      'category': category,
      'sellerId': sellerId,
      'sellerName': sellerName, // Added
      'isFeatured': isFeatured,
      'stock': stock,
      'rating': rating,
      'reviewCount': reviewCount, // Added
      'createdAt': createdAt,
    };
  }
}