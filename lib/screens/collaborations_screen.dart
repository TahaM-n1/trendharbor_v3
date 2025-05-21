// lib/screens/create_campaign_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PaymentType { escrow, upfront }

class CreateCampaignScreen extends StatefulWidget {
  const CreateCampaignScreen({super.key});

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen>
    with TickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  PaymentType _paymentType = PaymentType.escrow;
  String? _selectedProductId;
  List<String> _selectedInfluencerIds = [];
  List<Map<String, dynamic>> _userProducts = [];
  List<Map<String, dynamic>> _availableInfluencers = [];
  bool _isLoading = true;
  String _accountType = 'personal';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadUserData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accountType = prefs.getString('accountType') ?? 'personal';
    });

    // Check if user is authorized to create campaigns
    if (_accountType.toLowerCase() != 'organization') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showUnauthorizedDialog();
      });
      return;
    }

    _loadData();
  }

  void _showUnauthorizedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.red.shade400, size: 28),
              const SizedBox(width: 12),
              const Text('Access Denied'),
            ],
          ),
          content: const Text(
            'Only Organization accounts can create campaigns. Influencers can accept campaign invitations.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go Back'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadUserProducts(),
        _loadInfluencers(),
      ]);
      _animationController.forward();
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserProducts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: userId)
          .get();

      _userProducts = productsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'price': data['price'] ?? 0.0,
          'imageUrls': List<String>.from(data['imageUrls'] ?? []),
          'description': data['description'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error loading products: $e');
      rethrow;
    }
  }

  Future<void> _loadInfluencers() async {
    try {
      final influencersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('accountType', isEqualTo: 'Influencer')
          .get();

      _availableInfluencers = influencersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'username': data['username'] ?? 'Unknown',
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'accountType': data['accountType'] ?? 'Influencer',
        };
      }).toList();
    } catch (e) {
      print('Error loading influencers: $e');
      rethrow;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime initialDate = isStartDate
        ? _startDate ?? DateTime.now()
        : _endDate ?? _startDate ?? DateTime.now();

    final DateTime firstDate =
        isStartDate ? DateTime.now() : _startDate ?? DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Colors.deepPurple,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Widget _buildGradientCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.purple.shade50.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.purple.shade300],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSelector() {
    if (_userProducts.isEmpty) {
      return _buildGradientCard(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 60,
                  color: Colors.orange.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No products found',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need to have products to create a campaign',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return _buildGradientCard(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Select Product', Icons.inventory_2),
            const SizedBox(height: 16),
            ...(_userProducts.map((product) {
              final isSelected = _selectedProductId == product['id'];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedProductId = product['id'];
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                Colors.deepPurple.withOpacity(0.1),
                                Colors.purple.shade50,
                              ],
                            )
                          : null,
                      color: isSelected ? null : Colors.grey.shade50,
                      border: Border.all(
                        color: isSelected
                            ? Colors.deepPurple
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'product-${product['id']}',
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: _buildProductImage(product),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${product['price'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            })),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(Map<String, dynamic> product) {
    final imageUrls = product['imageUrls'] as List<String>;
    if (imageUrls.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          imageUrls[0],
          fit: BoxFit.cover,
          width: 70,
          height: 70,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade200,
              child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
            );
          },
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.image, color: Colors.grey[400]),
      );
    }
  }

  Widget _buildInfluencerSelector() {
    if (_availableInfluencers.isEmpty) {
      return _buildGradientCard(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.people_outline,
                  size: 60,
                  color: Colors.blue.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No influencers found',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool allSelected =
        _selectedInfluencerIds.length == _availableInfluencers.length;

    return _buildGradientCard(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Select Influencers', Icons.people),
                Row(
                  children: [
                    Checkbox(
                      value: allSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedInfluencerIds = _availableInfluencers
                                .map((i) => i['id'] as String)
                                .toList();
                          } else {
                            _selectedInfluencerIds.clear();
                          }
                        });
                      },
                      activeColor: Colors.deepPurple,
                    ),
                    const Text(
                      'Select All',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_selectedInfluencerIds.length} of ${_availableInfluencers.length} selected',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              child: SingleChildScrollView(
                child: Column(
                  children: _availableInfluencers.map((influencer) {
                    final isSelected =
                        _selectedInfluencerIds.contains(influencer['id']);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedInfluencerIds.add(influencer['id']);
                            } else {
                              _selectedInfluencerIds.remove(influencer['id']);
                            }
                          });
                        },
                        title: Text(
                          influencer['username'],
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          influencer['accountType'],
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        secondary: _buildInfluencerAvatar(influencer),
                        dense: true,
                        activeColor: Colors.deepPurple,
                        checkboxShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        tileColor: isSelected
                            ? Colors.deepPurple.withOpacity(0.05)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfluencerAvatar(Map<String, dynamic> influencer) {
    final profileImageUrl = influencer['profileImageUrl'] as String;

    if (profileImageUrl.isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.deepPurple.shade200,
        child: Text(
          influencer['username'].toString().isNotEmpty
              ? influencer['username'].toString()[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return CircleAvatar(
      backgroundImage: NetworkImage(profileImageUrl),
      backgroundColor: Colors.deepPurple.shade200,
      onBackgroundImageError: (exception, stackTrace) {},
    );
  }

  bool _validateForm() {
    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a campaign title');
      return false;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a campaign description');
      return false;
    }

    if (_startDate == null) {
      _showErrorSnackBar('Please select a start date');
      return false;
    }

    if (_endDate == null) {
      _showErrorSnackBar('Please select an end date');
      return false;
    }

    if (_selectedProductId == null) {
      _showErrorSnackBar('Please select a product');
      return false;
    }

    if (_selectedInfluencerIds.isEmpty) {
      _showErrorSnackBar('Please select at least one influencer');
      return false;
    }

    return true;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _saveCampaign() async {
    if (!_validateForm()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              ),
              const SizedBox(height: 16),
              Text(
                'Creating campaign...',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Create the campaignOffer map with all influencers set to false
      Map<String, bool> campaignOffer = {};
      for (String influencerId in _selectedInfluencerIds) {
        campaignOffer[influencerId] = false;
      }

      final campaignData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'productId': _selectedProductId!,
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'paymentType': _paymentType.toString().split('.').last,
        'invitedInfluencers': _selectedInfluencerIds,
        'campaignOffer': campaignOffer,
        'influencerBids': {}, // Initialize empty bids map
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      };

      // Create the campaign document
      final campaignDoc = await FirebaseFirestore.instance
          .collection('campaigns')
          .add(campaignData);

      // Update each invited influencer's userCampaigns field
      final batch = FirebaseFirestore.instance.batch();

      for (String influencerId in _selectedInfluencerIds) {
        final userDocRef =
            FirebaseFirestore.instance.collection('users').doc(influencerId);

        batch.update(userDocRef, {
          'userCampaigns.${campaignDoc.id}': false,
        });
      }

      // Commit the batch
      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(context).pop(); // Go back to campaigns screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Campaign created successfully'),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      print('Error saving campaign: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showErrorSnackBar('Error creating campaign: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading or unauthorized access check
    if (_accountType.toLowerCase() != 'organization') {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.deepPurple, Colors.purple.shade300],
              ),
            ),
          ),
          title: const Text(
            'Create Campaign',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple, Colors.purple.shade300],
            ),
          ),
        ),
        title: const Text(
          'Create Campaign',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // Show help dialog
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading campaign data...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Card
                    _buildGradientCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                                'Campaign Details', Icons.campaign),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'Campaign Title',
                                hintText: 'Enter campaign title',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.deepPurple,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: const Icon(Icons.title),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _descriptionController,
                              decoration: InputDecoration(
                                labelText: 'Campaign Description',
                                hintText: 'Describe your campaign',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.deepPurple,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: const Icon(Icons.description),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Date Selection Card
                    _buildGradientCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                                'Campaign Duration', Icons.date_range),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _selectDate(context, true),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: _startDate != null
                                              ? Colors.deepPurple
                                              : Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        color: _startDate != null
                                            ? Colors.deepPurple
                                                .withOpacity(0.05)
                                            : Colors.grey.shade50,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 16,
                                                color: _startDate != null
                                                    ? Colors.deepPurple
                                                    : Colors.grey,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Start Date',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _startDate != null
                                                ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                                : 'Select start date',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: _startDate != null
                                                  ? Colors.black87
                                                  : Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _selectDate(context, false),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: _endDate != null
                                              ? Colors.deepPurple
                                              : Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        color: _endDate != null
                                            ? Colors.deepPurple
                                                .withOpacity(0.05)
                                            : Colors.grey.shade50,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 16,
                                                color: _endDate != null
                                                    ? Colors.deepPurple
                                                    : Colors.grey,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'End Date',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _endDate != null
                                                ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                                : 'Select end date',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: _endDate != null
                                                  ? Colors.black87
                                                  : Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Payment Type Card
                    _buildGradientCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Payment Type', Icons.payment),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color:
                                            _paymentType == PaymentType.escrow
                                                ? Colors.deepPurple
                                                : Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      color: _paymentType == PaymentType.escrow
                                          ? Colors.deepPurple.withOpacity(0.05)
                                          : Colors.transparent,
                                    ),
                                    child: RadioListTile<PaymentType>(
                                      title: const Text(
                                        'Escrow',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: const Text(
                                        'Secure payment held until completion',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      value: PaymentType.escrow,
                                      groupValue: _paymentType,
                                      activeColor: Colors.deepPurple,
                                      onChanged: (value) {
                                        setState(() {
                                          _paymentType = value!;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color:
                                            _paymentType == PaymentType.upfront
                                                ? Colors.deepPurple
                                                : Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      color: _paymentType == PaymentType.upfront
                                          ? Colors.deepPurple.withOpacity(0.05)
                                          : Colors.transparent,
                                    ),
                                    child: RadioListTile<PaymentType>(
                                      title: const Text(
                                        'Upfront',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: const Text(
                                        'Immediate payment',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      value: PaymentType.upfront,
                                      groupValue: _paymentType,
                                      activeColor: Colors.deepPurple,
                                      onChanged: (value) {
                                        setState(() {
                                          _paymentType = value!;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Product Selection
                    _buildProductSelector(),

                    const SizedBox(height: 16),

                    // Influencer Selection
                    _buildInfluencerSelector(),

                    const SizedBox(height: 24),

                    // Save Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple, Colors.purple.shade300],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _saveCampaign,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Create Campaign',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
