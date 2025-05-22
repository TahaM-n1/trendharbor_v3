import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_order_model.dart';
import '../services/shop_service.dart';
import 'package:intl/intl.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({Key? key}) : super(key: key);

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  final ShopService _shopService = ShopService();
  List<ProductOrder> _orders = []; // Changed Order to ProductOrder
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final orders = await _shopService.getSellerOrders();
      if (mounted) {
        setState(() {
          _orders = orders; // No need for casting now
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading seller orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading orders: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      final success = await _shopService.updateOrderStatus(orderId, status);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order status updated successfully')),
          );
          _loadOrders(); // Reload orders to reflect changes
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update order status')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, yyyy - h:mm a').format(dateTime);
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'processing':
        return Colors.orange;
      case 'shipped':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No orders yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'When customers order your products,\nthey will appear here.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        title: Text(
                          'Order #${order.id.substring(0, 8)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(_formatDateTime(order.createdAt)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(order.status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getStatusColor(order.status),
                                    ),
                                  ),
                                  child: Text(
                                    _getStatusText(order.status),
                                    style: TextStyle(
                                      color: _getStatusColor(order.status),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Items',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...order.items
                                    .where((item) => item.sellerId == _shopService.currentUserId)
                                    .map((item) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 40,
                                                height: 40,
                                                child: item.imageUrl.isNotEmpty
                                                    ? Image.network(
                                                        item.imageUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) {
                                                          return Container(
                                                            color: Colors.grey[200],
                                                            child: const Icon(
                                                              Icons.image_not_supported,
                                                              size: 20,
                                                              color: Colors.grey,
                                                            ),
                                                          );
                                                        },
                                                      )
                                                    : Container(
                                                        color: Colors.grey[200],
                                                        child: const Icon(
                                                          Icons.image_not_supported,
                                                          size: 20,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.productName,
                                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                                    ),
                                                    Text(
                                                      '${item.quantity} x \$${item.price.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                '\$${(item.quantity * item.price).toStringAsFixed(2)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text(
                                  'Shipping Address',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(order.shippingAddress['name'] ?? ''),
                                Text(order.shippingAddress['address'] ?? ''),
                                Text(
                                  '${order.shippingAddress['city'] ?? ''}, ${order.shippingAddress['state'] ?? ''} ${order.shippingAddress['zip'] ?? ''}',
                                ),
                                Text(order.shippingAddress['phone'] ?? ''),
                                const SizedBox(height: 16),
                                if (order.status == 'processing')
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _updateOrderStatus(order.id, 'shipped'),
                                      icon: const Icon(Icons.local_shipping),
                                      label: const Text('Mark as Shipped'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                if (order.status == 'shipped')
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _updateOrderStatus(order.id, 'delivered'),
                                      icon: const Icon(Icons.check_circle),
                                      label: const Text('Mark as Delivered'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}