// // lib/screens/campaigns_screen.dart
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:trendharbor_v2/screens/collaborations_screen.dart';
// import '../widgets/bottom_navbar.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// // Add this import for CreateCampaignScreen
// // Uncomment the line below when you have the CreateCampaignScreen file
// // import 'package:trendharbor_v2/screens/create_campaign_screen.dart';

// class CampaignsScreen extends StatefulWidget {
//   const CampaignsScreen({super.key});

//   @override
//   State<CampaignsScreen> createState() => _CampaignsScreenState();
// }

// class _CampaignsScreenState extends State<CampaignsScreen>
//     with TickerProviderStateMixin {
//   String _accountType = 'personal';
//   late TabController _tabController;
//   late AnimationController _fabAnimationController;
//   late Animation<double> _fabAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//     _fabAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 300),
//       vsync: this,
//     );
//     _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _fabAnimationController,
//         curve: Curves.easeInOut,
//       ),
//     );
//     _loadUserData();
//     _fabAnimationController.forward();
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     _fabAnimationController.dispose();
//     super.dispose();
//   }

//   // Add the missing build method
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade50,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         title: const Text(
//           'Campaigns',
//           style: TextStyle(
//             color: Colors.black87,
//             fontWeight: FontWeight.bold,
//             fontSize: 24,
//           ),
//         ),
//         centerTitle: true,
//         bottom: TabBar(
//           controller: _tabController,
//           tabs: const [
//             Tab(
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.schedule, size: 18),
//                   SizedBox(width: 4),
//                   Text('Pending'),
//                 ],
//               ),
//             ),
//             Tab(
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.play_circle_filled, size: 18),
//                   SizedBox(width: 4),
//                   Text('Ongoing'),
//                 ],
//               ),
//             ),
//             Tab(
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.check_circle, size: 18),
//                   SizedBox(width: 4),
//                   Text('Completed'),
//                 ],
//               ),
//             ),
//           ],
//           labelColor: Colors.deepPurple,
//           unselectedLabelColor: Colors.grey,
//           indicatorColor: Colors.deepPurple,
//           indicatorWeight: 3,
//         ),
//         systemOverlayStyle: const SystemUiOverlayStyle(
//           statusBarColor: Colors.transparent,
//           statusBarIconBrightness: Brightness.dark,
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           _buildCampaignsTab('pending'),
//           _buildCampaignsTab('ongoing'),
//           _buildCampaignsTab('completed'),
//         ],
//       ),
//       floatingActionButton: _accountType.toLowerCase() == 'organization'
//           ? ScaleTransition(
//               scale: _fabAnimation,
//               child: FloatingActionButton.extended(
//                 onPressed: () {
//                   // Uncomment the next lines when you have CreateCampaignScreen
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => const CreateCampaignScreen(),
//                     ),
//                   );
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text('Create Campaign feature coming soon!'),
//                       behavior: SnackBarBehavior.floating,
//                     ),
//                   );
//                 },
//                 backgroundColor: Colors.deepPurple,
//                 icon: const Icon(Icons.add, color: Colors.white),
//                 label: const Text(
//                   'Create Campaign',
//                   style: TextStyle(
//                       color: Colors.white, fontWeight: FontWeight.w600),
//                 ),
//                 elevation: 4,
//                 heroTag: 'createCampaign',
//               ),
//             )
//           : null,
//       bottomNavigationBar: const BottomNavBar(),
//     );
//   }

//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     if (mounted) {
//       setState(() {
//         _accountType = prefs.getString('accountType') ?? 'personal';
//       });
//     }
//   }

//   String _getCampaignStatus(Map<String, dynamic> campaign) {
//     final startDate = (campaign['startDate'] as Timestamp).toDate();
//     final endDate = (campaign['endDate'] as Timestamp).toDate();
//     final now = DateTime.now();

//     // Get campaignOffer map
//     final campaignOffer =
//         Map<String, bool>.from(campaign['campaignOffer'] ?? {});

//     // Check if all users have accepted (all values are true)
//     final allAccepted = campaignOffer.values.every((accepted) => accepted);

//     if (allAccepted && now.isAfter(startDate) && now.isBefore(endDate)) {
//       // All accepted AND current date is between start and end dates
//       return 'ongoing';
//     } else if (allAccepted && now.isAfter(endDate)) {
//       // All accepted AND current date is after end date
//       return 'completed';
//     } else {
//       // Not all accepted OR before start date OR after end date without all accepted
//       return 'pending';
//     }
//   }

//   Future<Map<String, dynamic>?> _getProductDetails(String productId) async {
//     try {
//       final productDoc = await FirebaseFirestore.instance
//           .collection('products')
//           .doc(productId)
//           .get();

//       if (productDoc.exists) {
//         final data = productDoc.data()!;
//         return {
//           'name': data['name'] ?? 'Unknown Product',
//           'imageUrls': List<String>.from(data['imageUrls'] ?? []),
//           'price': data['price'] ?? 0.0,
//         };
//       }
//     } catch (e) {
//       print('Error fetching product details: $e');
//     }
//     return null;
//   }

//   Future<String> _getInfluencerUsername(String influencerId) async {
//     try {
//       final userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(influencerId)
//           .get();

//       if (userDoc.exists) {
//         final data = userDoc.data()!;
//         return data['username'] ?? 'Unknown User';
//       }
//     } catch (e) {
//       print('Error fetching user details: $e');
//     }
//     return 'Unknown User';
//   }

//   Widget _buildProductImage(Map<String, dynamic>? product) {
//     if (product == null) {
//       return Container(
//         width: 50,
//         height: 50,
//         decoration: BoxDecoration(
//           color: Colors.grey.shade200,
//           borderRadius: BorderRadius.circular(10),
//         ),
//         child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
//       );
//     }

//     final imageUrls = product['imageUrls'] as List<String>;
//     if (imageUrls.isNotEmpty) {
//       return Container(
//         width: 50,
//         height: 50,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(10),
//           border: Border.all(color: Colors.grey.shade200),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withOpacity(0.1),
//               spreadRadius: 1,
//               blurRadius: 3,
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(9),
//           child: Image.network(
//             imageUrls[0],
//             fit: BoxFit.cover,
//             errorBuilder: (context, error, stackTrace) {
//               return Container(
//                 color: Colors.grey.shade200,
//                 child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
//               );
//             },
//           ),
//         ),
//       );
//     } else {
//       return Container(
//         width: 50,
//         height: 50,
//         decoration: BoxDecoration(
//           color: Colors.grey.shade200,
//           borderRadius: BorderRadius.circular(10),
//         ),
//         child: Icon(Icons.image, color: Colors.grey[400]),
//       );
//     }
//   }

//   Color _getStatusColor(String status) {
//     switch (status) {
//       case 'pending':
//         return Colors.amber.shade600;
//       case 'ongoing':
//         return Colors.green.shade600;
//       case 'completed':
//         return Colors.blue.shade600;
//       default:
//         return Colors.grey;
//     }
//   }

//   String _getStatusText(String status) {
//     switch (status) {
//       case 'pending':
//         return _accountType.toLowerCase() == 'influencer'
//             ? 'Awaiting Response'
//             : 'Pending Acceptance';
//       case 'ongoing':
//         return 'In Progress';
//       case 'completed':
//         return 'Completed';
//       default:
//         return 'Unknown';
//     }
//   }

//   IconData _getStatusIcon(String status) {
//     switch (status) {
//       case 'pending':
//         return Icons.schedule;
//       case 'ongoing':
//         return Icons.play_circle_filled;
//       case 'completed':
//         return Icons.check_circle;
//       default:
//         return Icons.circle;
//     }
//   }

//   // Get bid status color based on state
//   Color _getBidStatusColor(String? status) {
//     switch (status) {
//       case 'accepted':
//         return Colors.green.shade600;
//       case 'escrow_pending':
//         return Colors.orange.shade600;
//       case 'in_progress':
//         return Colors.blue.shade600;
//       case 'completed':
//         return Colors.purple.shade600;
//       case 'declined':
//         return Colors.red.shade600;
//       case 'pending':
//       default:
//         return Colors.amber.shade600;
//     }
//   }

//   // Get bid status text
//   String _getBidStatusText(String? status) {
//     switch (status) {
//       case 'accepted':
//         return 'Accepted';
//       case 'escrow_pending':
//         return 'Payment Pending';
//       case 'in_progress':
//         return 'In Progress';
//       case 'completed':
//         return 'Completed';
//       case 'declined':
//         return 'Declined';
//       case 'pending':
//       default:
//         return 'Pending';
//     }
//   }

//   // Get bid status icon
//   IconData _getBidStatusIcon(String? status) {
//     switch (status) {
//       case 'accepted':
//         return Icons.check_circle;
//       case 'escrow_pending':
//         return Icons.payment;
//       case 'in_progress':
//         return Icons.work;
//       case 'completed':
//         return Icons.task_alt;
//       case 'declined':
//         return Icons.cancel;
//       case 'pending':
//       default:
//         return Icons.schedule;
//     }
//   }

//   Future<void> _acceptCampaignOffer(String campaignId) async {
//     final TextEditingController bidController = TextEditingController();
//     final TextEditingController descriptionController = TextEditingController();

//     final result = await showDialog<Map<String, dynamic>>(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           title: const Text('Accept Campaign Offer'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 TextField(
//                   controller: bidController,
//                   decoration: const InputDecoration(
//                     labelText: 'Your Bid/Fee (\$)',
//                     hintText: 'Enter your fee for this campaign',
//                     prefixIcon: Icon(Icons.attach_money),
//                     border: OutlineInputBorder(),
//                   ),
//                   keyboardType: TextInputType.number,
//                 ),
//                 const SizedBox(height: 16),
//                 TextField(
//                   controller: descriptionController,
//                   decoration: const InputDecoration(
//                     labelText: 'Description/Proposal',
//                     hintText: 'Describe what you will deliver',
//                     prefixIcon: Icon(Icons.description),
//                     border: OutlineInputBorder(),
//                   ),
//                   maxLines: 3,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (bidController.text.trim().isEmpty ||
//                     descriptionController.text.trim().isEmpty) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Please fill all fields')),
//                   );
//                   return;
//                 }
//                 Navigator.of(context).pop({
//                   'bid': double.tryParse(bidController.text) ?? 0.0,
//                   'description': descriptionController.text.trim(),
//                 });
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green.shade400,
//                 foregroundColor: Colors.white,
//               ),
//               child: const Text('Accept Offer'),
//             ),
//           ],
//         );
//       },
//     );

//     if (result != null) {
//       await _updateCampaignOffer(campaignId, true, result);
//     }
//   }

//   Future<void> _declineCampaignOffer(String campaignId) async {
//     final bool? confirm = await showDialog<bool>(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           title: const Text('Decline Campaign Offer'),
//           content: const Text(
//               'Are you sure you want to decline this campaign offer?'),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(false),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => Navigator.of(context).pop(true),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red.shade400,
//                 foregroundColor: Colors.white,
//               ),
//               child: const Text('Decline'),
//             ),
//           ],
//         );
//       },
//     );

//     if (confirm == true) {
//       await _updateCampaignOffer(campaignId, false, null);
//     }
//   }

//   Future<void> _updateCampaignOffer(
//       String campaignId, bool accept, Map<String, dynamic>? bidData) async {
//     final userId = FirebaseAuth.instance.currentUser?.uid;
//     if (userId == null) return;

//     try {
//       final batch = FirebaseFirestore.instance.batch();
//       final campaignRef =
//           FirebaseFirestore.instance.collection('campaigns').doc(campaignId);
//       final userRef =
//           FirebaseFirestore.instance.collection('users').doc(userId);

//       if (accept && bidData != null) {
//         // Accept the offer with bid data - add status field
//         final bidDataWithStatus = {
//           ...bidData,
//           'status': 'pending', // Pending organization approval
//         };

//         batch.update(campaignRef, {
//           'campaignOffer.$userId': true,
//           'influencerBids.$userId': bidDataWithStatus,
//         });
//         batch.update(userRef, {
//           'userCampaigns.$campaignId': true,
//         });
//       } else {
//         // Decline the offer - remove from campaignOffer
//         batch.update(campaignRef, {
//           'campaignOffer.$userId': FieldValue.delete(),
//           'influencerBids.$userId': FieldValue.delete(),
//         });
//         batch.update(userRef, {
//           'userCampaigns.$campaignId': FieldValue.delete(),
//         });
//       }

//       await batch.commit();

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(accept
//                 ? 'Campaign offer accepted!'
//                 : 'Campaign offer declined'),
//             backgroundColor:
//                 accept ? Colors.green.shade400 : Colors.red.shade400,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error updating campaign offer: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error: $e'),
//             backgroundColor: Colors.red.shade400,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     }
//   }

//   // Organization accepts an influencer's bid - now includes escrow workflow
//   Future<void> _acceptInfluencerBid(
//       String campaignId, String influencerId) async {
//     try {
//       await FirebaseFirestore.instance
//           .collection('campaigns')
//           .doc(campaignId)
//           .update({
//         'influencerBids.$influencerId.status': 'escrow_pending',
//       });

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: const Text(
//                 'Influencer bid accepted! Please make escrow payment to proceed.'),
//             backgroundColor: Colors.green.shade400,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }

//       // Show analytics dialog after accepting bid
//       Future.delayed(const Duration(milliseconds: 500), () {
//         if (mounted) {
//           _showAnalyticsOption(campaignId, influencerId);
//         }
//       });
//     } catch (e) {
//       print('Error accepting bid: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error accepting bid: $e'),
//             backgroundColor: Colors.red.shade400,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     }
//   }

//   // Add the missing _showAnalyticsOption method
//   Future<void> _showAnalyticsOption(
//       String campaignId, String influencerId) async {
//     // Get influencer name for the analytics screen
//     final influencerName = await _getInfluencerUsername(influencerId);

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           title: Row(
//             children: [
//               Icon(Icons.analytics, color: Colors.blue.shade600, size: 28),
//               const SizedBox(width: 12),
//               const Text('Campaign Analytics'),
//             ],
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 'Would you like to view analytics for this campaign?',
//                 style: TextStyle(
//                   color: Colors.grey[700],
//                   fontSize: 16,
//                 ),
//               ),
//               const SizedBox(height: 12),
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.blue.shade50,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(Icons.person, color: Colors.blue.shade600, size: 20),
//                     const SizedBox(width: 8),
//                     Text(
//                       'Influencer: $influencerName',
//                       style: TextStyle(
//                         color: Colors.blue.shade700,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Maybe Later'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _showAnalyticsScreen(campaignId, influencerId);
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue.shade600,
//                 foregroundColor: Colors.white,
//               ),
//               child: const Text('View Analytics'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // Show analytics screen in a dialog
//   Future<void> _showAnalyticsScreen(
//       String campaignId, String influencerId) async {
//     // Get campaign and influencer details
//     final campaignDoc = await FirebaseFirestore.instance
//         .collection('campaigns')
//         .doc(campaignId)
//         .get();

//     final campaignData = campaignDoc.data() as Map<String, dynamic>?;
//     final campaignTitle = campaignData?['title'] ?? 'Unknown Campaign';
//     final influencerName = await _getInfluencerUsername(influencerId);

//     if (!mounted) return;

//     showDialog(
//       context: context,
//       barrierDismissible: true,
//       builder: (BuildContext context) {
//         return Dialog(
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           child: AnalyticsScreen(
//             campaignId: campaignId,
//             influencerId: influencerId,
//             influencerName: influencerName,
//             campaignTitle: campaignTitle,
//           ),
//         );
//       },
//     );
//   }

//   // Organization declines an influencer's bid
//   Future<void> _declineInfluencerBid(
//       String campaignId, String influencerId) async {
//     try {
//       await FirebaseFirestore.instance
//           .collection('campaigns')
//           .doc(campaignId)
//           .update({
//         'influencerBids.$influencerId.status': 'declined',
//       });

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: const Text('Influencer bid declined'),
//             backgroundColor: Colors.orange.shade400,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error declining bid: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error declining bid: $e'),
//             backgroundColor: Colors.red.shade400,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     }
//   }

//   // Escrow payment dialog for campaigns
//   Future<void> _showEscrowPaymentDialog(
//       String campaignId, String influencerId, double bidAmount) async {
//     showDialog(
//       context: context,
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: const Text('Make Escrow Payment'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Icon(Icons.account_balance_wallet,
//                   size: 60, color: Colors.blue),
//               const SizedBox(height: 16),
//               Text(
//                 'Make escrow payment of \$${bidAmount.toStringAsFixed(2)}',
//                 style:
//                     const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 8),
//               const Text(
//                 'This simulates an escrow payment for the campaign.',
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 8),
//               const Text(
//                 'In a real application, this would connect to a payment processor.',
//                 style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
//                 textAlign: TextAlign.center,
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(dialogContext).pop();
//               },
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.of(dialogContext).pop();
//                 _makeEscrowPayment(campaignId, influencerId);
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 foregroundColor: Colors.white,
//               ),
//               child: const Text('Make Payment'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // Process escrow payment for campaign
//   Future<void> _makeEscrowPayment(
//       String campaignId, String influencerId) async {
//     try {
//       final Timestamp now = Timestamp.now();
//       final User? currentUser = FirebaseAuth.instance.currentUser;
//       if (currentUser == null) return;

//       // Get campaign details to extract productId
//       final campaignDoc = await FirebaseFirestore.instance
//           .collection('campaigns')
//           .doc(campaignId)
//           .get();

//       final campaignData = campaignDoc.data() as Map<String, dynamic>?;
//       final productId = campaignData?['productId'] as String?;

//       // Create batch operation
//       final batch = FirebaseFirestore.instance.batch();

//       // Update campaign with payment status
//       final campaignRef =
//           FirebaseFirestore.instance.collection('campaigns').doc(campaignId);
//       batch.update(campaignRef, {
//         'influencerBids.$influencerId.status': 'in_progress',
//         'influencerBids.$influencerId.escrowPaidBy': currentUser.uid,
//         'influencerBids.$influencerId.escrowPaidAt':
//             FieldValue.serverTimestamp(),
//       });

//       // Add productId to influencer's paidProducts list
//       if (productId != null) {
//         final influencerRef =
//             FirebaseFirestore.instance.collection('users').doc(influencerId);
//         batch.update(influencerRef, {
//           'paidProducts': FieldValue.arrayUnion([productId]),
//         });
//       }

//       // Commit the batch
//       await batch.commit();

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content:
//                 Text('Escrow payment completed! Campaign is now in progress.'),
//             backgroundColor: Colors.green,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error making escrow payment: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error making escrow payment: $e'),
//             backgroundColor: Colors.red,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     }
//   }

//   // Create a post for the campaign (influencers only, after payment)
//   Future<void> _createCampaignPost(
//       String campaignId, String influencerId) async {
//     try {
//       final currentUser = FirebaseAuth.instance.currentUser;
//       if (currentUser == null) return;

//       // Verify current user is the influencer for this bid
//       if (currentUser.uid != influencerId) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('You can only create posts for your own campaigns'),
//               backgroundColor: Colors.red,
//               behavior: SnackBarBehavior.floating,
//             ),
//           );
//         }
//         return;
//       }

//       // Get campaign details
//       final campaignDoc = await FirebaseFirestore.instance
//           .collection('campaigns')
//           .doc(campaignId)
//           .get();

//       final campaignData = campaignDoc.data() as Map<String, dynamic>?;
//       if (campaignData == null) return;

//       // Verify the bid is in progress and payment has been made
//       final bidData = campaignData['influencerBids']?[influencerId]
//           as Map<String, dynamic>?;
//       if (bidData == null || bidData['status'] != 'in_progress') {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content:
//                   Text('Campaign must be in progress before creating a post'),
//               backgroundColor: Colors.orange,
//               behavior: SnackBarBehavior.floating,
//             ),
//           );
//         }
//         return;
//       }

//       // Get product details for the post
//       final productId = campaignData['productId'] as String?;
//       if (productId == null) return;

//       final productDoc = await FirebaseFirestore.instance
//           .collection('products')
//           .doc(productId)
//           .get();

//       final productData = productDoc.data() as Map<String, dynamic>?;
//       if (productData == null) return;

//       // Get current user data
//       final userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(currentUser.uid)
//           .get();

//       final userData = userDoc.data() as Map<String, dynamic>?;
//       if (userData == null) return;

//       // Create post data matching the Post model structure exactly
//       final postData = {
//         'user': userData, // Store the entire user document (matches User model)
//         'imageUrl': (productData['imageUrls'] as List?)?.isNotEmpty == true
//             ? productData['imageUrls'][0]
//             : '',
//         'caption': productData['description'] ??
//             'Check out this amazing product!', // Use product description, not campaign description
//         'likes': 0,
//         'comments': 0,
//         'liked': false,
//         'createdAt': FieldValue.serverTimestamp(), // Add timestamp for posts
//       };

//       // Save post to Firestore
//       await FirebaseFirestore.instance.collection('posts').add(postData);

//       // Update the bid status to indicate post has been created
//       await FirebaseFirestore.instance
//           .collection('campaigns')
//           .doc(campaignId)
//           .update({
//         'influencerBids.$influencerId.postCreated': true,
//         'influencerBids.$influencerId.postCreatedAt':
//             FieldValue.serverTimestamp(),
//       });

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Campaign post created successfully!'),
//             backgroundColor: Colors.green,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error creating campaign post: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error creating post: $e'),
//             backgroundColor: Colors.red,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     }
//   }

//   // Mark campaign as completed
//   Future<void> _markCampaignAsCompleted(
//       String campaignId, String influencerId) async {
//     try {
//       final Timestamp now = Timestamp.now();
//       final User? currentUser = FirebaseAuth.instance.currentUser;
//       if (currentUser == null) return;

//       await FirebaseFirestore.instance
//           .collection('campaigns')
//           .doc(campaignId)
//           .update({
//         'influencerBids.$influencerId.status': 'completed',
//         'influencerBids.$influencerId.completedAt':
//             FieldValue.serverTimestamp(),
//         'influencerBids.$influencerId.completedBy': currentUser.uid,
//       });

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Campaign work marked as completed!'),
//             backgroundColor: Colors.green,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error marking campaign as completed: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error: $e'),
//             backgroundColor: Colors.red,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     }
//   }

//   Future<void> _deleteCampaign(
//       String campaignId, Map<String, dynamic> campaign) async {
//     // Only allow organizations to delete campaigns
//     if (_accountType.toLowerCase() != 'organization') return;

//     // Show confirmation dialog
//     final bool? confirmDelete = await showDialog<bool>(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           title: Row(
//             children: [
//               Icon(Icons.warning, color: Colors.red.shade400, size: 28),
//               const SizedBox(width: 12),
//               const Text('Delete Campaign'),
//             ],
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Are you sure you want to delete "${campaign['title']}"?',
//                 style: const TextStyle(fontWeight: FontWeight.w500),
//               ),
//               const SizedBox(height: 8),
//               const Text(
//                 'This action cannot be undone. All related data will be permanently removed.',
//                 style: TextStyle(color: Colors.grey),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(false),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => Navigator.of(context).pop(true),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red.shade400,
//                 foregroundColor: Colors.white,
//               ),
//               child: const Text('Delete'),
//             ),
//           ],
//         );
//       },
//     );

//     if (confirmDelete != true) return;

//     // Show loading dialog
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => Center(
//         child: Container(
//           padding: const EdgeInsets.all(24),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 'Deleting campaign...',
//                 style: TextStyle(color: Colors.grey[700], fontSize: 16),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );

//     try {
//       // Get invited influencers list
//       final List<String> invitedInfluencers =
//           List<String>.from(campaign['invitedInfluencers'] ?? []);

//       // Create batch for atomic operations
//       final batch = FirebaseFirestore.instance.batch();

//       // Delete the campaign document
//       final campaignDocRef =
//           FirebaseFirestore.instance.collection('campaigns').doc(campaignId);
//       batch.delete(campaignDocRef);

//       // Remove campaign reference from all invited influencers
//       for (String influencerId in invitedInfluencers) {
//         final userDocRef =
//             FirebaseFirestore.instance.collection('users').doc(influencerId);

//         batch.update(userDocRef, {
//           'userCampaigns.$campaignId': FieldValue.delete(),
//         });
//       }

//       // Commit the batch
//       await batch.commit();

//       if (mounted) {
//         Navigator.of(context).pop(); // Close loading dialog
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content:
//                 Text('Campaign "${campaign['title']}" deleted successfully'),
//             backgroundColor: Colors.green.shade400,
//             behavior: SnackBarBehavior.floating,
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error deleting campaign: $e');
//       if (mounted) {
//         Navigator.of(context).pop(); // Close loading dialog
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error deleting campaign: $e'),
//             backgroundColor: Colors.red.shade400,
//             behavior: SnackBarBehavior.floating,
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//           ),
//         );
//       }
//     }
//   }

//   // NEW FUNCTION: Build a section for influencers to create posts
//   Widget _buildInfluencerActionSection(
//       Map<String, dynamic> campaign, String campaignId) {
//     final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
//     if (userId.isEmpty || _accountType.toLowerCase() != 'influencer') {
//       return const SizedBox.shrink();
//     }

//     // Get this influencer's bid data from the campaign
//     final influencerBids = Map<String, Map<String, dynamic>>.from(
//         (campaign['influencerBids'] ?? {}).map((key, value) =>
//             MapEntry(key, Map<String, dynamic>.from(value ?? {}))));

//     // Check if this influencer has a bid with 'in_progress' status
//     final bidData = influencerBids[userId];
//     final status = bidData?['status']?.toString() ?? '';
//     final postCreated = bidData?['postCreated'] == true;

//     // Only show post section if the bid is in progress (payment received)
//     if (status != 'in_progress' || bidData == null) {
//       return const SizedBox.shrink();
//     }

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.purple.shade50,
//         border: Border(
//           top: BorderSide(color: Colors.purple.shade200),
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           if (!postCreated) ...[
//             Row(
//               children: [
//                 Icon(Icons.camera_alt, color: Colors.purple.shade700, size: 20),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     'Ready to create your campaign post?',
//                     style: TextStyle(
//                       fontWeight: FontWeight.w600,
//                       color: Colors.purple.shade700,
//                       fontSize: 16,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Share this product with your followers to complete your campaign!',
//               style: TextStyle(
//                 color: Colors.purple.shade600,
//                 fontSize: 14,
//               ),
//             ),
//             const SizedBox(height: 12),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 onPressed: () => _createCampaignPost(campaignId, userId),
//                 icon: const Icon(Icons.add_photo_alternate, size: 18),
//                 label: const Text('Create Post'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.purple,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                 ),
//               ),
//             ),
//           ] else ...[
//             // Post has been created, show success message
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.green.shade50,
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: Colors.green.shade200),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.check_circle,
//                       color: Colors.green.shade600, size: 20),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'Campaign post created successfully! 🎉',
//                       style: TextStyle(
//                         color: Colors.green.shade700,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 12),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 onPressed: () => _markCampaignAsCompleted(campaignId, userId),
//                 icon: const Icon(Icons.task_alt, size: 18),
//                 label: const Text('Mark Campaign as Completed'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.indigo,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                 ),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildInfluencerBidsSection(
//       Map<String, dynamic> campaign, String campaignId) {
//     final influencerBids = Map<String, Map<String, dynamic>>.from(
//         (campaign['influencerBids'] ?? {}).map((key, value) =>
//             MapEntry(key, Map<String, dynamic>.from(value ?? {}))));

//     if (influencerBids.isEmpty) return const SizedBox.shrink();

//     return Column(
//       children: [
//         Container(
//           width: double.infinity,
//           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//           decoration: BoxDecoration(
//             color: Colors.blue.shade50,
//             border: Border(
//               top: BorderSide(color: Colors.grey.shade200, width: 1),
//               bottom: BorderSide(color: Colors.grey.shade200, width: 1),
//             ),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 'Influencer Bids (${influencerBids.length})',
//                 style: TextStyle(
//                   fontWeight: FontWeight.w600,
//                   color: Colors.blue.shade700,
//                   fontSize: 14,
//                 ),
//               ),
//               if (_accountType.toLowerCase() == 'organization') ...[
//                 Container(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: Colors.blue.shade100,
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Text(
//                     'Review & Pay',
//                     style: TextStyle(
//                       color: Colors.blue.shade700,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//         ...influencerBids.entries.map((entry) {
//           final influencerId = entry.key;
//           final bidData = entry.value;
//           final bid = bidData['bid']?.toString() ?? '0';
//           final bidAmount = (bidData['bid'] as num?)?.toDouble() ?? 0.0;
//           final description = bidData['description']?.toString() ?? '';
//           final status = bidData['status']?.toString() ?? 'pending';
//           final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

//           return FutureBuilder<String>(
//             future: _getInfluencerUsername(influencerId),
//             builder: (context, snapshot) {
//               final username = snapshot.data ?? 'Loading...';
//               return Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   border: Border(
//                     bottom: BorderSide(color: Colors.grey.shade100),
//                   ),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           username,
//                           style: const TextStyle(
//                             fontWeight: FontWeight.w600,
//                             fontSize: 16,
//                           ),
//                         ),
//                         Row(
//                           children: [
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 8, vertical: 4),
//                               decoration: BoxDecoration(
//                                 color: Colors.green.shade100,
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Text(
//                                 '\$$bid',
//                                 style: TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.green.shade700,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 8, vertical: 4),
//                               decoration: BoxDecoration(
//                                 color:
//                                     _getBidStatusColor(status).withOpacity(0.1),
//                                 borderRadius: BorderRadius.circular(8),
//                                 border: Border.all(
//                                   color: _getBidStatusColor(status),
//                                   width: 1,
//                                 ),
//                               ),
//                               child: Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   Icon(
//                                     _getBidStatusIcon(status),
//                                     size: 14,
//                                     color: _getBidStatusColor(status),
//                                   ),
//                                   const SizedBox(width: 4),
//                                   Text(
//                                     _getBidStatusText(status),
//                                     style: TextStyle(
//                                       color: _getBidStatusColor(status),
//                                       fontWeight: FontWeight.w600,
//                                       fontSize: 12,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                     if (description.isNotEmpty) ...[
//                       const SizedBox(height: 8),
//                       Text(
//                         description,
//                         style: TextStyle(
//                           color: Colors.grey.shade700,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ],
//                     // Show action buttons based on status and user type
//                     if (_accountType.toLowerCase() == 'organization' &&
//                         status == 'pending') ...[
//                       const SizedBox(height: 12),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: OutlinedButton.icon(
//                               onPressed: () => _declineInfluencerBid(
//                                   campaignId, influencerId),
//                               icon: const Icon(Icons.close, size: 18),
//                               label: const Text('Decline'),
//                               style: OutlinedButton.styleFrom(
//                                 foregroundColor: Colors.red.shade400,
//                                 side: BorderSide(color: Colors.red.shade400),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: ElevatedButton.icon(
//                               onPressed: () => _acceptInfluencerBid(
//                                   campaignId, influencerId),
//                               icon: const Icon(Icons.check, size: 18),
//                               label: const Text('Accept & Proceed'),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.green.shade400,
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ] else if (_accountType.toLowerCase() == 'organization' &&
//                         status == 'escrow_pending') ...[
//                       const SizedBox(height: 12),
//                       Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: Colors.orange.shade50,
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(color: Colors.orange.shade200),
//                         ),
//                         child: Column(
//                           children: [
//                             Row(
//                               children: [
//                                 Icon(Icons.payment,
//                                     color: Colors.orange.shade600, size: 20),
//                                 const SizedBox(width: 8),
//                                 Expanded(
//                                   child: Text(
//                                     'Escrow payment required to proceed',
//                                     style: TextStyle(
//                                       color: Colors.orange.shade700,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 12),
//                             SizedBox(
//                               width: double.infinity,
//                               child: ElevatedButton.icon(
//                                 onPressed: () => _showEscrowPaymentDialog(
//                                     campaignId, influencerId, bidAmount),
//                                 icon: const Icon(Icons.account_balance_wallet,
//                                     size: 18),
//                                 label: Text(
//                                     'Make Escrow Payment (\${bidAmount.toStringAsFixed(2)})'),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.blue,
//                                   foregroundColor: Colors.white,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ] else if (status == 'in_progress' &&
//                         influencerId == userId) ...[
//                       // Only the specific influencer who received payment can create posts and mark as completed
//                       const SizedBox(height: 12),

//                       // Check if post has been created
//                       if (bidData['postCreated'] != true) ...[
//                         // Show create post button first - only for the specific influencer
//                         Container(
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: Colors.purple.shade50,
//                             borderRadius: BorderRadius.circular(8),
//                             border: Border.all(color: Colors.purple.shade200),
//                           ),
//                           child: Column(
//                             children: [
//                               Row(
//                                 children: [
//                                   Icon(Icons.camera_alt,
//                                       color: Colors.purple.shade600, size: 20),
//                                   const SizedBox(width: 8),
//                                   Expanded(
//                                     child: Text(
//                                       'Payment received! Create your campaign post now',
//                                       style: TextStyle(
//                                         color: Colors.purple.shade700,
//                                         fontWeight: FontWeight.w500,
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 8),
//                               Text(
//                                 'Show off this product to your followers!',
//                                 style: TextStyle(
//                                   color: Colors.purple.shade600,
//                                   fontSize: 12,
//                                   fontStyle: FontStyle.italic,
//                                 ),
//                               ),
//                               const SizedBox(height: 12),
//                               SizedBox(
//                                 width: double.infinity,
//                                 child: ElevatedButton.icon(
//                                   onPressed: () => _createCampaignPost(
//                                       campaignId, influencerId),
//                                   icon: const Icon(Icons.add_photo_alternate,
//                                       size: 18),
//                                   label: const Text('Create Campaign Post'),
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: Colors.purple,
//                                     foregroundColor: Colors.white,
//                                     shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(8),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(height: 12),
//                       ] else ...[
//                         // Post has been created, show success indicator
//                         Container(
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: Colors.green.shade50,
//                             borderRadius: BorderRadius.circular(8),
//                             border: Border.all(color: Colors.green.shade200),
//                           ),
//                           child: Row(
//                             children: [
//                               Icon(Icons.check_circle,
//                                   color: Colors.green.shade600, size: 20),
//                               const SizedBox(width: 8),
//                               Expanded(
//                                 child: Text(
//                                   'Campaign post created successfully! 🎉',
//                                   style: TextStyle(
//                                     color: Colors.green.shade700,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(height: 12),
//                       ],

//                       // Show mark as completed button only after post is created
//                       if (bidData['postCreated'] == true) ...[
//                         SizedBox(
//                           width: double.infinity,
//                           child: ElevatedButton.icon(
//                             onPressed: () => _markCampaignAsCompleted(
//                                 campaignId, influencerId),
//                             icon: const Icon(Icons.task_alt, size: 18),
//                             label: const Text('Mark Campaign as Completed'),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.indigo,
//                               foregroundColor: Colors.white,
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ] else if (status == 'in_progress' &&
//                         _accountType.toLowerCase() == 'influencer' &&
//                         influencerId != userId) ...[
//                       // Other influencers see that this one is in progress
//                       const SizedBox(height: 12),
//                       Container(
//                         padding: const EdgeInsets.all(8),
//                         decoration: BoxDecoration(
//                           color: Colors.blue.shade50,
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Row(
//                           children: [
//                             Icon(Icons.info,
//                                 color: Colors.blue.shade600, size: 16),
//                             const SizedBox(width: 8),
//                             Text(
//                               'This influencer\'s campaign is in progress',
//                               style: TextStyle(
//                                 color: Colors.blue.shade600,
//                                 fontSize: 12,
//                                 fontStyle: FontStyle.italic,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ] else if (status == 'completed') ...[
//                       // Show completion info
//                       const SizedBox(height: 12),
//                       Container(
//                         padding: const EdgeInsets.all(8),
//                         decoration: BoxDecoration(
//                           color: Colors.green.shade50,
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Row(
//                           children: [
//                             Icon(Icons.check_circle,
//                                 color: Colors.green.shade600, size: 16),
//                             const SizedBox(width: 8),
//                             Text(
//                               'Campaign work completed',
//                               style: TextStyle(
//                                 color: Colors.green.shade600,
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               );
//             },
//           );
//         }).toList(),
//       ],
//     );
//   }

//   Widget _buildBeautifulCampaignCard(
//       Map<String, dynamic> campaign, String campaignId) {
//     final status = _getCampaignStatus(campaign);
//     final startDate = (campaign['startDate'] as Timestamp).toDate();
//     final endDate = (campaign['endDate'] as Timestamp).toDate();
//     final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

//     // Get acceptance information
//     final campaignOffer =
//         Map<String, bool>.from(campaign['campaignOffer'] ?? {});
//     final acceptedCount =
//         campaignOffer.values.where((accepted) => accepted).length;
//     final totalInvited = campaignOffer.length;

//     // Check if current user is invited (for influencers)
//     final isUserInvited = campaignOffer.containsKey(userId);
//     final hasUserAccepted = campaignOffer[userId] ?? false;

//     // Define card colors based on status and user type
//     Color cardStartColor;
//     Color cardEndColor;
//     Color borderColor;

//     switch (status) {
//       case 'pending':
//         cardStartColor = Colors.amber.shade50;
//         cardEndColor = Colors.orange.shade50;
//         borderColor = Colors.amber.shade200;
//         break;
//       case 'ongoing':
//         cardStartColor = Colors.green.shade50;
//         cardEndColor = Colors.teal.shade50;
//         borderColor = Colors.green.shade200;
//         break;
//       case 'completed':
//         cardStartColor = Colors.blue.shade50;
//         cardEndColor = Colors.indigo.shade50;
//         borderColor = Colors.blue.shade200;
//         break;
//       default:
//         cardStartColor = Colors.grey.shade50;
//         cardEndColor = Colors.grey.shade100;
//         borderColor = Colors.grey.shade200;
//     }

//     // Special styling for influencer cards based on their acceptance status
//     if (_accountType.toLowerCase() == 'influencer' && isUserInvited) {
//       if (hasUserAccepted) {
//         cardStartColor = Colors.purple.shade50;
//         cardEndColor = Colors.deepPurple.shade50;
//         borderColor = Colors.purple.shade200;
//       } else {
//         cardStartColor = Colors.yellow.shade50;
//         cardEndColor = Colors.amber.shade50;
//         borderColor = Colors.yellow.shade200;
//       }
//     }

//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(20),
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [cardStartColor, cardEndColor],
//         ),
//         border: Border.all(color: borderColor, width: 1.5),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.15),
//             spreadRadius: 2,
//             blurRadius: 12,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           // Header section
//           Container(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Expanded(
//                       child: Text(
//                         campaign['title'] ?? 'Untitled Campaign',
//                         style: const TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 18,
//                           color: Colors.black87,
//                         ),
//                       ),
//                     ),
//                     Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 12, vertical: 6),
//                           decoration: BoxDecoration(
//                             color: _getStatusColor(status).withOpacity(0.15),
//                             borderRadius: BorderRadius.circular(20),
//                             border: Border.all(
//                               color: _getStatusColor(status),
//                               width: 1.5,
//                             ),
//                           ),
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(
//                                 _getStatusIcon(status),
//                                 size: 16,
//                                 color: _getStatusColor(status),
//                               ),
//                               const SizedBox(width: 4),
//                               Text(
//                                 _getStatusText(status),
//                                 style: TextStyle(
//                                   color: _getStatusColor(status),
//                                   fontWeight: FontWeight.w600,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         // Only show delete option for Organizations
//                         if (_accountType.toLowerCase() == 'organization') ...[
//                           const SizedBox(width: 8),
//                           PopupMenuButton<String>(
//                             icon: Icon(
//                               Icons.more_vert,
//                               color: Colors.grey.shade600,
//                             ),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             onSelected: (value) {
//                               if (value == 'delete') {
//                                 _deleteCampaign(campaignId, campaign);
//                               }
//                             },
//                             itemBuilder: (context) => [
//                               PopupMenuItem<String>(
//                                 value: 'delete',
//                                 child: Row(
//                                   children: [
//                                     Icon(Icons.delete,
//                                         color: Colors.red.shade400, size: 20),
//                                     const SizedBox(width: 8),
//                                     Text(
//                                       'Delete Campaign',
//                                       style:
//                                           TextStyle(color: Colors.red.shade400),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ],
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 12),
//                 Text(
//                   campaign['description'] ?? 'No description',
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(
//                     color: Colors.grey[700],
//                     fontSize: 14,
//                     height: 1.4,
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Row(
//                   children: [
//                     _buildInfoChip(
//                       Icons.calendar_today,
//                       '${startDate.day}/${startDate.month}/${startDate.year}',
//                       Colors.blue.shade600,
//                     ),
//                     const SizedBox(width: 12),
//                     _buildInfoChip(
//                       Icons.event,
//                       '${endDate.day}/${endDate.month}/${endDate.year}',
//                       Colors.green.shade600,
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 12),
//                 Row(
//                   children: [
//                     _buildInfoChip(
//                       Icons.payment,
//                       campaign['paymentType']?.toString().toUpperCase() ??
//                           'UNKNOWN',
//                       Colors.deepPurple,
//                     ),
//                     const Spacer(),
//                     _buildInfoChip(
//                       Icons.people,
//                       '$acceptedCount/$totalInvited Accepted',
//                       acceptedCount == totalInvited
//                           ? Colors.green.shade600
//                           : Colors.orange.shade600,
//                     ),
//                   ],
//                 ),

//                 // Show action buttons for influencers
//                 if (_accountType.toLowerCase() == 'influencer' &&
//                     isUserInvited &&
//                     !hasUserAccepted) ...[
//                   const SizedBox(height: 16),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: OutlinedButton.icon(
//                           onPressed: () => _declineCampaignOffer(campaignId),
//                           icon: const Icon(Icons.close, size: 18),
//                           label: const Text('Decline'),
//                           style: OutlinedButton.styleFrom(
//                             foregroundColor: Colors.red.shade400,
//                             side: BorderSide(color: Colors.red.shade400),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: ElevatedButton.icon(
//                           onPressed: () => _acceptCampaignOffer(campaignId),
//                           icon: const Icon(Icons.check, size: 18),
//                           label: const Text('Accept'),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.green.shade400,
//                             foregroundColor: Colors.white,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ] else if (_accountType.toLowerCase() == 'influencer' &&
//                     hasUserAccepted) ...[
//                   const SizedBox(height: 16),
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.green.shade50,
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: Colors.green.shade200),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(Icons.check_circle,
//                             color: Colors.green.shade600, size: 20),
//                         const SizedBox(width: 8),
//                         Text(
//                           'You have accepted this campaign',
//                           style: TextStyle(
//                             color: Colors.green.shade700,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),

//           // Product section with improved styling
//           FutureBuilder<Map<String, dynamic>?>(
//             future: _getProductDetails(campaign['productId']),
//             builder: (context, snapshot) {
//               if (snapshot.hasData && snapshot.data != null) {
//                 final product = snapshot.data!;
//                 return Container(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.8),
//                     border: Border.symmetric(
//                       horizontal: BorderSide(color: borderColor, width: 1),
//                     ),
//                   ),
//                   child: Row(
//                     children: [
//                       _buildProductImage(product),
//                       const SizedBox(width: 16),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               product['name'],
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.w600,
//                                 fontSize: 16,
//                                 color: Colors.black87,
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               '\$${(product['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
//                               style: TextStyle(
//                                 color: Colors.green.shade600,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 18,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Container(
//                         padding: const EdgeInsets.all(8),
//                         decoration: BoxDecoration(
//                           color: Colors.deepPurple.withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Icon(
//                           Icons.arrow_forward_ios,
//                           size: 16,
//                           color: Colors.deepPurple,
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               }
//               return Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.8),
//                   border: Border.symmetric(
//                     horizontal: BorderSide(color: borderColor, width: 1),
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     _buildProductImage(null),
//                     const SizedBox(width: 16),
//                     const Expanded(
//                       child: Text(
//                         'Loading product details...',
//                         style: TextStyle(color: Colors.grey),
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           ),

//           // Add influencer post creation section for influencers
//           if (_accountType.toLowerCase() == 'influencer')
//             _buildInfluencerActionSection(campaign, campaignId),

//           // Influencer bids section (only for organizations)
//           if (_accountType.toLowerCase() == 'organization')
//             _buildInfluencerBidsSection(campaign, campaignId),

//           // Bottom border
//           Container(
//             height: 1,
//             decoration: BoxDecoration(
//               borderRadius: const BorderRadius.only(
//                 bottomLeft: Radius.circular(20),
//                 bottomRight: Radius.circular(20),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildInfoChip(IconData icon, String text, Color color) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 14, color: color),
//           const SizedBox(width: 4),
//           Text(
//             text,
//             style: TextStyle(
//               color: color,
//               fontWeight: FontWeight.w500,
//               fontSize: 12,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Stream<QuerySnapshot> _getCampaignsStream(String status) {
//     final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
//     if (userId.isEmpty) {
//       return const Stream.empty();
//     }

//     if (_accountType.toLowerCase() == 'influencer') {
//       // For influencers, get campaigns where they are invited
//       return FirebaseFirestore.instance
//           .collection('campaigns')
//           .where('campaignOffer.$userId', isNotEqualTo: null)
//           .snapshots();
//     } else {
//       // For organizations, get campaigns they created
//       return FirebaseFirestore.instance
//           .collection('campaigns')
//           .where('createdBy', isEqualTo: userId)
//           .snapshots();
//     }
//   }

//   Widget _buildCampaignsTab(String status) {
//     final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
//     if (userId.isEmpty) {
//       return const Center(
//           child: Text('You must be logged in to view campaigns'));
//     }

//     return StreamBuilder<QuerySnapshot>(
//       stream: _getCampaignsStream(status),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const CircularProgressIndicator(
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                   'Loading campaigns...',
//                   style: TextStyle(color: Colors.grey[600]),
//                 ),
//               ],
//             ),
//           );
//         }

//         if (snapshot.hasError) {
//           return Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
//                 const SizedBox(height: 16),
//                 Text('Error loading campaigns'),
//                 const SizedBox(height: 8),
//                 Text(
//                   'Please try again later',
//                   style: TextStyle(color: Colors.grey[600], fontSize: 14),
//                 ),
//               ],
//             ),
//           );
//         }

//         final allCampaigns = snapshot.data?.docs ?? [];

//         // Filter campaigns based on status and sort by createdAt on client side
//         final filteredCampaigns = allCampaigns.where((doc) {
//           final campaign = doc.data() as Map<String, dynamic>;
//           final campaignStatus = _getCampaignStatus(campaign);

//           // For influencers, also filter pending based on whether they've responded
//           if (_accountType.toLowerCase() == 'influencer' &&
//               status == 'pending') {
//             final campaignOffer =
//                 Map<String, bool>.from(campaign['campaignOffer'] ?? {});
//             final hasUserResponded = campaignOffer.containsKey(userId) &&
//                 campaignOffer[userId] == true;
//             // Only show in pending if they haven't accepted yet
//             return campaignStatus == 'pending' && !hasUserResponded;
//           }

//           return campaignStatus == status;
//         }).toList();

//         // Sort by createdAt on client side (descending)
//         filteredCampaigns.sort((a, b) {
//           final aData = a.data() as Map<String, dynamic>;
//           final bData = b.data() as Map<String, dynamic>;
//           final aTime =
//               (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
//           final bTime =
//               (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
//           return bTime.compareTo(aTime);
//         });

//         if (filteredCampaigns.isEmpty) {
//           return _buildEmptyState(status);
//         }

//         return ListView.builder(
//           padding: const EdgeInsets.only(top: 8, bottom: 100),
//           itemCount: filteredCampaigns.length,
//           itemBuilder: (context, index) {
//             final campaign =
//                 filteredCampaigns[index].data() as Map<String, dynamic>;
//             return AnimatedContainer(
//               duration: Duration(milliseconds: 300 + (index * 100)),
//               child: _buildBeautifulCampaignCard(
//                   campaign, filteredCampaigns[index].id),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildEmptyState(String status) {
//     String message;
//     IconData icon;
//     String actionText;

//     if (_accountType.toLowerCase() == 'influencer') {
//       switch (status) {
//         case 'pending':
//           message = 'No pending campaign invitations';
//           icon = Icons.inbox;
//           actionText = 'Waiting for campaign invitations';
//           break;
//         case 'ongoing':
//           message = 'No active campaigns';
//           icon = Icons.work_outline;
//           actionText = 'Accept invitations to start campaigns';
//           break;
//         case 'completed':
//           message = 'No completed campaigns yet';
//           icon = Icons.check_circle_outline;
//           actionText = 'Complete your campaigns';
//           break;
//         default:
//           message = 'No campaigns found';
//           icon = Icons.campaign;
//           actionText = 'No campaigns available';
//       }
//     } else {
//       switch (status) {
//         case 'pending':
//           message = 'No pending campaigns';
//           icon = Icons.schedule;
//           actionText = 'Create your first campaign';
//           break;
//         case 'ongoing':
//           message = 'No active campaigns';
//           icon = Icons.work_outline;
//           actionText = 'Start a campaign today';
//           break;
//         case 'completed':
//           message = 'No completed campaigns yet';
//           icon = Icons.check_circle_outline;
//           actionText = 'Complete your first campaign';
//           break;
//         default:
//           message = 'No campaigns found';
//           icon = Icons.campaign;
//           actionText = 'Create a campaign';
//       }
//     }

//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(24),
//             decoration: BoxDecoration(
//               color: Colors.grey.shade100,
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: Icon(icon, size: 60, color: Colors.grey[400]),
//           ),
//           const SizedBox(height: 20),
//           Text(
//             message,
//             style: const TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.w600,
//               color: Colors.grey,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             actionText,
//             style: TextStyle(
//               fontSize: 14,
//               color: Colors.grey[600],
//             ),
//           ),
//           if (status == 'pending' &&
//               _accountType.toLowerCase() == 'organization') ...[
//             const SizedBox(height: 24),
//             ElevatedButton.icon(
//               onPressed: () {
//                 // Uncomment the next lines when you have CreateCampaignScreen
//                 // Navigator.push(
//                 //   context,
//                 //   MaterialPageRoute(
//                 //     builder: (context) => const CreateCampaignScreen(),
//                 //   ),
//                 // );
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Create Campaign feature coming soon!'),
//                     behavior: SnackBarBehavior.floating,
//                   ),
//                 );
//               },
//               icon: const Icon(Icons.add),
//               label: const Text('Create Campaign'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.deepPurple,
//                 foregroundColor: Colors.white,
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }

// // Add this Analytics Screen Widget at the end of the file
// class AnalyticsScreen extends StatefulWidget {
//   final String campaignId;
//   final String influencerId;
//   final String influencerName;
//   final String campaignTitle;

//   const AnalyticsScreen({
//     Key? key,
//     required this.campaignId,
//     required this.influencerId,
//     required this.influencerName,
//     required this.campaignTitle,
//   }) : super(key: key);

//   @override
//   State<AnalyticsScreen> createState() => _AnalyticsScreenState();
// }

// class _AnalyticsScreenState extends State<AnalyticsScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   bool _isLoading = true;

//   // Dummy analytics data
//   final Map<String, dynamic> _analyticsData = {
//     'impressions': 4287,
//     'engagement': 842,
//     'clicks': 356,
//     'conversion': 28,
//     'roi': 3.7,
//     'likes': 523,
//     'comments': 89,
//     'shares': 127,
//     'saves': 75,
//     'timeSpent': 2.8, // minutes
//   };

//   // Daily engagement data for charts (7 days)
//   final List<Map<String, dynamic>> _dailyData = [
//     {'day': 'Mon', 'likes': 42, 'comments': 8, 'shares': 12},
//     {'day': 'Tue', 'likes': 67, 'comments': 12, 'shares': 15},
//     {'day': 'Wed', 'likes': 103, 'comments': 18, 'shares': 26},
//     {'day': 'Thu', 'likes': 89, 'comments': 14, 'shares': 21},
//     {'day': 'Fri', 'likes': 118, 'comments': 22, 'shares': 31},
//     {'day': 'Sat', 'likes': 76, 'comments': 11, 'shares': 16},
//     {'day': 'Sun', 'likes': 28, 'comments': 4, 'shares': 6},
//   ];

//   // Demographic data
//   final List<Map<String, dynamic>> _demographicData = [
//     {'age': '18-24', 'percentage': 32},
//     {'age': '25-34', 'percentage': 41},
//     {'age': '35-44', 'percentage': 18},
//     {'age': '45-54', 'percentage': 7},
//     {'age': '55+', 'percentage': 2},
//   ];

//   // Geographic data
//   final List<Map<String, dynamic>> _geographicData = [
//     {'region': 'North America', 'percentage': 43},
//     {'region': 'Europe', 'percentage': 28},
//     {'region': 'Asia', 'percentage': 18},
//     {'region': 'South America', 'percentage': 7},
//     {'region': 'Other', 'percentage': 4},
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);

//     // Simulate loading data
//     Future.delayed(const Duration(seconds: 1), () {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   // Build a metric card for key stats
//   Widget _buildMetricCard(
//       String title, dynamic value, IconData icon, Color color) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             spreadRadius: 1,
//             blurRadius: 6,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: color, size: 20),
//               const SizedBox(width: 8),
//               Text(
//                 title,
//                 style: TextStyle(
//                   color: Colors.grey[600],
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text(
//             value.toString(),
//             style: TextStyle(
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//               color: Colors.grey[800],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Build engagement chart
//   Widget _buildEngagementChart() {
//     return Container(
//       height: 250,
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             spreadRadius: 1,
//             blurRadius: 6,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Daily Engagement',
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//               color: Colors.grey[800],
//             ),
//           ),
//           const SizedBox(height: 16),
//           Expanded(
//             child: CustomPaint(
//               size: const Size(double.infinity, 200),
//               painter: ChartPainter(_dailyData),
//             ),
//           ),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               _buildLegendItem('Likes', Colors.blue),
//               const SizedBox(width: 16),
//               _buildLegendItem('Comments', Colors.green),
//               const SizedBox(width: 16),
//               _buildLegendItem('Shares', Colors.purple),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // Build legend item
//   Widget _buildLegendItem(String label, Color color) {
//     return Row(
//       children: [
//         Container(
//           width: 12,
//           height: 12,
//           decoration: BoxDecoration(
//             color: color,
//             borderRadius: BorderRadius.circular(4),
//           ),
//         ),
//         const SizedBox(width: 4),
//         Text(
//           label,
//           style: TextStyle(
//             color: Colors.grey[600],
//             fontSize: 12,
//           ),
//         ),
//       ],
//     );
//   }

//   // Build demographic chart
//   Widget _buildDemographicChart() {
//     return Container(
//       height: 250,
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             spreadRadius: 1,
//             blurRadius: 6,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Age Demographics',
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//               color: Colors.grey[800],
//             ),
//           ),
//           const SizedBox(height: 16),
//           Expanded(
//             child: Row(
//               children: [
//                 SizedBox(
//                   width: 100,
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: _demographicData.map((data) {
//                       return Text(
//                         '${data['age']}: ${data['percentage']}%',
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: Colors.grey[700],
//                         ),
//                       );
//                     }).toList(),
//                   ),
//                 ),
//                 Expanded(
//                   child: CustomPaint(
//                     size: const Size(double.infinity, 200),
//                     painter: PieChartPainter(_demographicData),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: MediaQuery.of(context).size.width * 0.9,
//       height: MediaQuery.of(context).size.height * 0.8,
//       padding: const EdgeInsets.all(16),
//       child: _isLoading
//           ? const Center(
//               child: CircularProgressIndicator(),
//             )
//           : Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Campaign Analytics',
//                           style: TextStyle(
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.grey[800],
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           widget.campaignTitle,
//                           style: TextStyle(
//                             fontSize: 16,
//                             color: Colors.grey[600],
//                           ),
//                         ),
//                       ],
//                     ),
//                     IconButton(
//                       onPressed: () => Navigator.of(context).pop(),
//                       icon: const Icon(Icons.close),
//                       color: Colors.grey[600],
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Container(
//                   padding:
//                       const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                   decoration: BoxDecoration(
//                     color: Colors.purple.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(Icons.person, color: Colors.purple[700], size: 16),
//                       const SizedBox(width: 8),
//                       Text(
//                         'Influencer: ${widget.influencerName}',
//                         style: TextStyle(
//                           color: Colors.purple[700],
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 // Tab bar
//                 TabBar(
//                   controller: _tabController,
//                   labelColor: Colors.purple[700],
//                   unselectedLabelColor: Colors.grey[600],
//                   indicatorColor: Colors.purple[700],
//                   tabs: const [
//                     Tab(text: 'Overview'),
//                     Tab(text: 'Engagement'),
//                     Tab(text: 'Demographics'),
//                   ],
//                 ),
//                 const SizedBox(height: 16),
//                 // Tab content
//                 Expanded(
//                   child: TabBarView(
//                     controller: _tabController,
//                     children: [
//                       // Overview tab
//                       SingleChildScrollView(
//                         child: Column(
//                           children: [
//                             GridView.count(
//                               shrinkWrap: true,
//                               physics: const NeverScrollableScrollPhysics(),
//                               crossAxisCount: 2,
//                               childAspectRatio: 1.5,
//                               crossAxisSpacing: 16,
//                               mainAxisSpacing: 16,
//                               children: [
//                                 _buildMetricCard(
//                                     'Impressions',
//                                     _analyticsData['impressions'],
//                                     Icons.visibility,
//                                     Colors.blue),
//                                 _buildMetricCard(
//                                     'Engagement',
//                                     '${(_analyticsData['engagement'] / _analyticsData['impressions'] * 100).toStringAsFixed(1)}%',
//                                     Icons.thumb_up,
//                                     Colors.green),
//                                 _buildMetricCard(
//                                     'Click Rate',
//                                     '${(_analyticsData['clicks'] / _analyticsData['impressions'] * 100).toStringAsFixed(1)}%',
//                                     Icons.touch_app,
//                                     Colors.amber),
//                                 _buildMetricCard(
//                                     'ROI',
//                                     '${_analyticsData['roi'].toStringAsFixed(1)}x',
//                                     Icons.attach_money,
//                                     Colors.purple),
//                               ],
//                             ),
//                             const SizedBox(height: 16),
//                             _buildEngagementChart(),
//                           ],
//                         ),
//                       ),
//                       // Engagement tab
//                       SingleChildScrollView(
//                         child: Column(
//                           children: [
//                             GridView.count(
//                               shrinkWrap: true,
//                               physics: const NeverScrollableScrollPhysics(),
//                               crossAxisCount: 2,
//                               childAspectRatio: 1.5,
//                               crossAxisSpacing: 16,
//                               mainAxisSpacing: 16,
//                               children: [
//                                 _buildMetricCard(
//                                     'Likes',
//                                     _analyticsData['likes'],
//                                     Icons.favorite,
//                                     Colors.red),
//                                 _buildMetricCard(
//                                     'Comments',
//                                     _analyticsData['comments'],
//                                     Icons.chat_bubble,
//                                     Colors.blue),
//                                 _buildMetricCard(
//                                     'Shares',
//                                     _analyticsData['shares'],
//                                     Icons.share,
//                                     Colors.green),
//                                 _buildMetricCard(
//                                     'Saves',
//                                     _analyticsData['saves'],
//                                     Icons.bookmark,
//                                     Colors.amber),
//                               ],
//                             ),
//                             const SizedBox(height: 16),
//                             Container(
//                               padding: const EdgeInsets.all(16),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(16),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.grey.withOpacity(0.1),
//                                     spreadRadius: 1,
//                                     blurRadius: 6,
//                                     offset: const Offset(0, 3),
//                                   ),
//                                 ],
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     'Engagement Summary',
//                                     style: TextStyle(
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.grey[800],
//                                     ),
//                                   ),
//                                   const SizedBox(height: 16),
//                                   Row(
//                                     children: [
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               'Total Engagement',
//                                               style: TextStyle(
//                                                 color: Colors.grey[600],
//                                                 fontSize: 14,
//                                               ),
//                                             ),
//                                             const SizedBox(height: 4),
//                                             Text(
//                                               _analyticsData['engagement']
//                                                   .toString(),
//                                               style: TextStyle(
//                                                 fontSize: 20,
//                                                 fontWeight: FontWeight.bold,
//                                                 color: Colors.grey[800],
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               'Engagement Rate',
//                                               style: TextStyle(
//                                                 color: Colors.grey[600],
//                                                 fontSize: 14,
//                                               ),
//                                             ),
//                                             const SizedBox(height: 4),
//                                             Text(
//                                               '${(_analyticsData['engagement'] / _analyticsData['impressions'] * 100).toStringAsFixed(1)}%',
//                                               style: TextStyle(
//                                                 fontSize: 20,
//                                                 fontWeight: FontWeight.bold,
//                                                 color: Colors.grey[800],
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       // Demographics tab
//                       SingleChildScrollView(
//                         child: Column(
//                           children: [
//                             _buildDemographicChart(),
//                             const SizedBox(height: 16),
//                             Container(
//                               padding: const EdgeInsets.all(16),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(16),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.grey.withOpacity(0.1),
//                                     spreadRadius: 1,
//                                     blurRadius: 6,
//                                     offset: const Offset(0, 3),
//                                   ),
//                                 ],
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     'Geographic Distribution',
//                                     style: TextStyle(
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.grey[800],
//                                     ),
//                                   ),
//                                   const SizedBox(height: 16),
//                                   ..._geographicData.map((data) {
//                                     return Padding(
//                                       padding: const EdgeInsets.only(bottom: 8),
//                                       child: Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment.start,
//                                         children: [
//                                           Row(
//                                             children: [
//                                               Text(
//                                                 data['region'],
//                                                 style: TextStyle(
//                                                   color: Colors.grey[700],
//                                                   fontSize: 14,
//                                                 ),
//                                               ),
//                                               const Spacer(),
//                                               Text(
//                                                 '${data['percentage']}%',
//                                                 style: TextStyle(
//                                                   color: Colors.grey[700],
//                                                   fontSize: 14,
//                                                   fontWeight: FontWeight.bold,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                           const SizedBox(height: 4),
//                                           LinearProgressIndicator(
//                                             value: data['percentage'] / 100,
//                                             backgroundColor: Colors.grey[200],
//                                             valueColor:
//                                                 AlwaysStoppedAnimation<Color>(
//                                               _getRegionColor(data['region']),
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     );
//                                   }).toList(),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }

//   Color _getRegionColor(String region) {
//     switch (region) {
//       case 'North America':
//         return Colors.blue;
//       case 'Europe':
//         return Colors.green;
//       case 'Asia':
//         return Colors.orange;
//       case 'South America':
//         return Colors.purple;
//       default:
//         return Colors.grey;
//     }
//   }
// }

// // Custom chart painter for engagement
// class ChartPainter extends CustomPainter {
//   final List<Map<String, dynamic>> data;

//   ChartPainter(this.data);

//   @override
//   void paint(Canvas canvas, Size size) {
//     // Find max values for scaling
//     double maxLikes = 0;
//     double maxComments = 0;
//     double maxShares = 0;

//     for (var item in data) {
//       if (item['likes'] > maxLikes) maxLikes = item['likes'].toDouble();
//       if (item['comments'] > maxComments)
//         maxComments = item['comments'].toDouble();
//       if (item['shares'] > maxShares) maxShares = item['shares'].toDouble();
//     }

//     final double maxValue =
//         [maxLikes, maxComments, maxShares].reduce((a, b) => a > b ? a : b);

//     // Calculate bar width
//     final double barWidth = size.width / (data.length * 3 + 1);
//     final double barSpacing = barWidth / 2;

//     // Define paints
//     final Paint likesPaint = Paint()
//       ..color = Colors.blue
//       ..style = PaintingStyle.fill;

//     final Paint commentsPaint = Paint()
//       ..color = Colors.green
//       ..style = PaintingStyle.fill;

//     final Paint sharesPaint = Paint()
//       ..color = Colors.purple
//       ..style = PaintingStyle.fill;

//     // Draw grid lines
//     final Paint gridPaint = Paint()
//       ..color = Colors.grey.withOpacity(0.2)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1;

//     // Draw horizontal grid lines
//     for (int i = 0; i <= 4; i++) {
//       double y = size.height - (size.height * i / 4);
//       canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
//     }

//     // Draw bars
//     for (int i = 0; i < data.length; i++) {
//       var item = data[i];

//       // X position for group of bars
//       double x = i * (barWidth * 3 + barSpacing) + barSpacing;

//       // Likes bar
//       double likesHeight = (item['likes'] / maxValue) * size.height;
//       canvas.drawRect(
//         Rect.fromLTWH(x, size.height - likesHeight, barWidth, likesHeight),
//         likesPaint,
//       );

//       // Comments bar
//       double commentsHeight = (item['comments'] / maxValue) * size.height;
//       canvas.drawRect(
//         Rect.fromLTWH(x + barWidth, size.height - commentsHeight, barWidth,
//             commentsHeight),
//         commentsPaint,
//       );

//       // Shares bar
//       double sharesHeight = (item['shares'] / maxValue) * size.height;
//       canvas.drawRect(
//         Rect.fromLTWH(x + barWidth * 2, size.height - sharesHeight, barWidth,
//             sharesHeight),
//         sharesPaint,
//       );

//       // Day label
//       TextPainter textPainter = TextPainter(
//         text: TextSpan(
//           text: item['day'],
//           style: TextStyle(
//             color: Colors.grey[600],
//             fontSize: 10,
//           ),
//         ),
//         textDirection: TextDirection.ltr,
//       );

//       textPainter.layout();
//       textPainter.paint(
//         canvas,
//         Offset(x + barWidth, size.height + 5),
//       );
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }

// // Custom pie chart painter for demographics
// class PieChartPainter extends CustomPainter {
//   final List<Map<String, dynamic>> data;

//   PieChartPainter(this.data);

//   @override
//   void paint(Canvas canvas, Size size) {
//     final Paint paint = Paint()..style = PaintingStyle.fill;

//     // Calculate total for percentages
//     final double total =
//         data.fold(0, (sum, item) => sum + item['percentage'] as double);

//     // Define colors for each segment
//     final List<Color> colors = [
//       Colors.blue,
//       Colors.green,
//       Colors.orange,
//       Colors.purple,
//       Colors.teal,
//     ];

//     // Draw pie segments
//     double startAngle = 0;
//     for (int i = 0; i < data.length; i++) {
//       final percentage = data[i]['percentage'] / total;
//       final sweepAngle = percentage * 2 * 3.14159; // Convert to radians

//       paint.color = colors[i % colors.length];

//       canvas.drawArc(
//         Rect.fromCircle(
//           center: Offset(size.width / 2, size.height / 2),
//           radius: size.width / 3,
//         ),
//         startAngle,
//         sweepAngle,
//         true,
//         paint,
//       );

//       startAngle += sweepAngle;
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }

// lib/screens/campaigns_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trendharbor_v2/screens/collaborations_screen.dart';
import '../widgets/bottom_navbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Add this import for CreateCampaignScreen
// Uncomment the line below when you have the CreateCampaignScreen file
// import 'package:trendharbor_v2/screens/create_campaign_screen.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen>
    with TickerProviderStateMixin {
  String _accountType = 'personal';
  late TabController _tabController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _loadUserData();
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  // Add the missing build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Campaigns',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 18),
                  SizedBox(width: 4),
                  Text('Pending'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_filled, size: 18),
                  SizedBox(width: 4),
                  Text('Ongoing'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 18),
                  SizedBox(width: 4),
                  Text('Completed'),
                ],
              ),
            ),
          ],
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          indicatorWeight: 3,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCampaignsTab('pending'),
          _buildCampaignsTab('ongoing'),
          _buildCampaignsTab('completed'),
        ],
      ),
      floatingActionButton: _accountType.toLowerCase() == 'organization'
          ? ScaleTransition(
              scale: _fabAnimation,
              child: FloatingActionButton.extended(
                onPressed: () {
                  // Uncomment the next lines when you have CreateCampaignScreen
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => const CreateCampaignScreen(),
                  //   ),
                  // );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Create Campaign feature coming soon!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                backgroundColor: Colors.deepPurple,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Create Campaign',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                elevation: 4,
                heroTag: 'createCampaign',
              ),
            )
          : null,
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _accountType = prefs.getString('accountType') ?? 'personal';
      });
    }
  }

  String _getCampaignStatus(Map<String, dynamic> campaign) {
    final startDate = (campaign['startDate'] as Timestamp).toDate();
    final endDate = (campaign['endDate'] as Timestamp).toDate();
    final now = DateTime.now();

    // Get campaignOffer map
    final campaignOffer =
        Map<String, bool>.from(campaign['campaignOffer'] ?? {});

    // Check if all users have accepted (all values are true)
    final allAccepted = campaignOffer.values.every((accepted) => accepted);

    if (allAccepted && now.isAfter(startDate) && now.isBefore(endDate)) {
      // All accepted AND current date is between start and end dates
      return 'ongoing';
    } else if (allAccepted && now.isAfter(endDate)) {
      // All accepted AND current date is after end date
      return 'completed';
    } else {
      // Not all accepted OR before start date OR after end date without all accepted
      return 'pending';
    }
  }

  Future<Map<String, dynamic>?> _getProductDetails(String productId) async {
    try {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (productDoc.exists) {
        final data = productDoc.data()!;
        return {
          'name': data['name'] ?? 'Unknown Product',
          'imageUrls': List<String>.from(data['imageUrls'] ?? []),
          'price': data['price'] ?? 0.0,
        };
      }
    } catch (e) {
      print('Error fetching product details: $e');
    }
    return null;
  }

  Future<String> _getInfluencerUsername(String influencerId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(influencerId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        return data['username'] ?? 'Unknown User';
      }
    } catch (e) {
      print('Error fetching user details: $e');
    }
    return 'Unknown User';
  }

  Widget _buildProductImage(Map<String, dynamic>? product) {
    if (product == null) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
      );
    }

    final imageUrls = product['imageUrls'] as List<String>;
    if (imageUrls.isNotEmpty) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.network(
            imageUrls[0],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade200,
                child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
              );
            },
          ),
        ),
      );
    } else {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.image, color: Colors.grey[400]),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber.shade600;
      case 'ongoing':
        return Colors.green.shade600;
      case 'completed':
        return Colors.blue.shade600;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return _accountType.toLowerCase() == 'influencer'
            ? 'Awaiting Response'
            : 'Pending Acceptance';
      case 'ongoing':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'ongoing':
        return Icons.play_circle_filled;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.circle;
    }
  }

  // Get bid status color based on state
  Color _getBidStatusColor(String? status) {
    switch (status) {
      case 'accepted':
        return Colors.green.shade600;
      case 'escrow_pending':
        return Colors.orange.shade600;
      case 'in_progress':
        return Colors.blue.shade600;
      case 'completed':
        return Colors.purple.shade600;
      case 'declined':
        return Colors.red.shade600;
      case 'pending':
      default:
        return Colors.amber.shade600;
    }
  }

  // Get bid status text
  String _getBidStatusText(String? status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'escrow_pending':
        return 'Payment Pending';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'declined':
        return 'Declined';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  // Get bid status icon
  IconData _getBidStatusIcon(String? status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'escrow_pending':
        return Icons.payment;
      case 'in_progress':
        return Icons.work;
      case 'completed':
        return Icons.task_alt;
      case 'declined':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.schedule;
    }
  }

  Future<void> _acceptCampaignOffer(String campaignId) async {
    final TextEditingController bidController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Accept Campaign Offer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bidController,
                  decoration: const InputDecoration(
                    labelText: 'Your Bid/Fee (\$)',
                    hintText: 'Enter your fee for this campaign',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description/Proposal',
                    hintText: 'Describe what you will deliver',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (bidController.text.trim().isEmpty ||
                    descriptionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }
                Navigator.of(context).pop({
                  'bid': double.tryParse(bidController.text) ?? 0.0,
                  'description': descriptionController.text.trim(),
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade400,
                foregroundColor: Colors.white,
              ),
              child: const Text('Accept Offer'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await _updateCampaignOffer(campaignId, true, result);
    }
  }

  Future<void> _declineCampaignOffer(String campaignId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Decline Campaign Offer'),
          content: const Text(
              'Are you sure you want to decline this campaign offer?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
              ),
              child: const Text('Decline'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _updateCampaignOffer(campaignId, false, null);
    }
  }

  Future<void> _updateCampaignOffer(
      String campaignId, bool accept, Map<String, dynamic>? bidData) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final campaignRef =
          FirebaseFirestore.instance.collection('campaigns').doc(campaignId);
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(userId);

      if (accept && bidData != null) {
        // Accept the offer with bid data - add status field
        final bidDataWithStatus = {
          ...bidData,
          'status': 'pending', // Pending organization approval
        };

        batch.update(campaignRef, {
          'campaignOffer.$userId': true,
          'influencerBids.$userId': bidDataWithStatus,
        });
        batch.update(userRef, {
          'userCampaigns.$campaignId': true,
        });
      } else {
        // Decline the offer - remove from campaignOffer
        batch.update(campaignRef, {
          'campaignOffer.$userId': FieldValue.delete(),
          'influencerBids.$userId': FieldValue.delete(),
        });
        batch.update(userRef, {
          'userCampaigns.$campaignId': FieldValue.delete(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept
                ? 'Campaign offer accepted!'
                : 'Campaign offer declined'),
            backgroundColor:
                accept ? Colors.green.shade400 : Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error updating campaign offer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Organization accepts an influencer's bid - now includes escrow workflow
  Future<void> _acceptInfluencerBid(
      String campaignId, String influencerId) async {
    try {
      await FirebaseFirestore.instance
          .collection('campaigns')
          .doc(campaignId)
          .update({
        'influencerBids.$influencerId.status': 'escrow_pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Influencer bid accepted! Please make escrow payment to proceed.'),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Show analytics dialog after accepting bid
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showAnalyticsOption(campaignId, influencerId);
        }
      });
    } catch (e) {
      print('Error accepting bid: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting bid: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Add the missing _showAnalyticsOption method
  Future<void> _showAnalyticsOption(
      String campaignId, String influencerId) async {
    // Get influencer name for the analytics screen
    final influencerName = await _getInfluencerUsername(influencerId);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue.shade600, size: 28),
              const SizedBox(width: 12),
              const Text('Campaign Analytics'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Would you like to view analytics for this campaign?',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Influencer: $influencerName',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showAnalyticsScreen(campaignId, influencerId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('View Analytics'),
            ),
          ],
        );
      },
    );
  }

  // Show analytics screen in a dialog
  Future<void> _showAnalyticsScreen(
      String campaignId, String influencerId) async {
    // Get campaign and influencer details
    final campaignDoc = await FirebaseFirestore.instance
        .collection('campaigns')
        .doc(campaignId)
        .get();

    final campaignData = campaignDoc.data() as Map<String, dynamic>?;
    final campaignTitle = campaignData?['title'] ?? 'Unknown Campaign';
    final influencerName = await _getInfluencerUsername(influencerId);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: AnalyticsScreen(
            campaignId: campaignId,
            influencerId: influencerId,
            influencerName: influencerName,
            campaignTitle: campaignTitle,
          ),
        );
      },
    );
  }

  // Organization declines an influencer's bid
  Future<void> _declineInfluencerBid(
      String campaignId, String influencerId) async {
    try {
      await FirebaseFirestore.instance
          .collection('campaigns')
          .doc(campaignId)
          .update({
        'influencerBids.$influencerId.status': 'declined',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Influencer bid declined'),
            backgroundColor: Colors.orange.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error declining bid: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining bid: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Escrow payment dialog for campaigns
  Future<void> _showEscrowPaymentDialog(
      String campaignId, String influencerId, double bidAmount) async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Make Escrow Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet,
                  size: 60, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                'Make escrow payment of \$${bidAmount.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'This simulates an escrow payment for the campaign.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'In a real application, this would connect to a payment processor.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _makeEscrowPayment(campaignId, influencerId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Make Payment'),
            ),
          ],
        );
      },
    );
  }

  // Process escrow payment for campaign
  Future<void> _makeEscrowPayment(
      String campaignId, String influencerId) async {
    try {
      final Timestamp now = Timestamp.now();
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get campaign details to extract productId
      final campaignDoc = await FirebaseFirestore.instance
          .collection('campaigns')
          .doc(campaignId)
          .get();

      final campaignData = campaignDoc.data() as Map<String, dynamic>?;
      final productId = campaignData?['productId'] as String?;

      // Create batch operation
      final batch = FirebaseFirestore.instance.batch();

      // Update campaign with payment status
      final campaignRef =
          FirebaseFirestore.instance.collection('campaigns').doc(campaignId);
      batch.update(campaignRef, {
        'influencerBids.$influencerId.status': 'in_progress',
        'influencerBids.$influencerId.escrowPaidBy': currentUser.uid,
        'influencerBids.$influencerId.escrowPaidAt':
            FieldValue.serverTimestamp(),
      });

      // Add productId to influencer's paidProducts list
      if (productId != null) {
        final influencerRef =
            FirebaseFirestore.instance.collection('users').doc(influencerId);
        batch.update(influencerRef, {
          'paidProducts': FieldValue.arrayUnion([productId]),
        });
      }

      // Commit the batch
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Escrow payment completed! Campaign is now in progress.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error making escrow payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making escrow payment: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Create a post for the campaign (influencers only, after payment)
  Future<void> _createCampaignPost(
      String campaignId, String influencerId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Verify current user is the influencer for this bid
      if (currentUser.uid != influencerId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can only create posts for your own campaigns'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Get campaign details
      final campaignDoc = await FirebaseFirestore.instance
          .collection('campaigns')
          .doc(campaignId)
          .get();

      final campaignData = campaignDoc.data() as Map<String, dynamic>?;
      if (campaignData == null) return;

      // Verify the bid is in progress and payment has been made
      final bidData = campaignData['influencerBids']?[influencerId]
          as Map<String, dynamic>?;
      if (bidData == null || bidData['status'] != 'in_progress') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Campaign must be in progress before creating a post'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Get product details for the post
      final productId = campaignData['productId'] as String?;
      if (productId == null) return;

      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      final productData = productDoc.data() as Map<String, dynamic>?;
      if (productData == null) return;

      // Get current user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) return;

      // Create post data matching the Post model structure exactly
      final postData = {
        'user': userData, // Store the entire user document (matches User model)
        'imageUrl': (productData['imageUrls'] as List?)?.isNotEmpty == true
            ? productData['imageUrls'][0]
            : '',
        'caption': productData['description'] ??
            'Check out this amazing product!', // Use product description, not campaign description
        'likes': 0,
        'comments': 0,
        'liked': false,
        'createdAt': FieldValue.serverTimestamp(), // Add timestamp for posts
      };

      // Save post to Firestore
      await FirebaseFirestore.instance.collection('posts').add(postData);

      // Update the bid status to indicate post has been created
      await FirebaseFirestore.instance
          .collection('campaigns')
          .doc(campaignId)
          .update({
        'influencerBids.$influencerId.postCreated': true,
        'influencerBids.$influencerId.postCreatedAt':
            FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campaign post created successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error creating campaign post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating post: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Mark campaign as completed
  Future<void> _markCampaignAsCompleted(
      String campaignId, String influencerId) async {
    try {
      final Timestamp now = Timestamp.now();
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('campaigns')
          .doc(campaignId)
          .update({
        'influencerBids.$influencerId.status': 'completed',
        'influencerBids.$influencerId.completedAt':
            FieldValue.serverTimestamp(),
        'influencerBids.$influencerId.completedBy': currentUser.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campaign work marked as completed!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error marking campaign as completed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteCampaign(
      String campaignId, Map<String, dynamic> campaign) async {
    // Only allow organizations to delete campaigns
    if (_accountType.toLowerCase() != 'organization') return;

    // Show confirmation dialog
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade400, size: 28),
              const SizedBox(width: 12),
              const Text('Delete Campaign'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete "${campaign['title']}"?',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone. All related data will be permanently removed.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return;

    // Show loading dialog
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
                'Deleting campaign...',
                style: TextStyle(color: Colors.grey[700], fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Get invited influencers list
      final List<String> invitedInfluencers =
          List<String>.from(campaign['invitedInfluencers'] ?? []);

      // Create batch for atomic operations
      final batch = FirebaseFirestore.instance.batch();

      // Delete the campaign document
      final campaignDocRef =
          FirebaseFirestore.instance.collection('campaigns').doc(campaignId);
      batch.delete(campaignDocRef);

      // Remove campaign reference from all invited influencers
      for (String influencerId in invitedInfluencers) {
        final userDocRef =
            FirebaseFirestore.instance.collection('users').doc(influencerId);

        batch.update(userDocRef, {
          'userCampaigns.$campaignId': FieldValue.delete(),
        });
      }

      // Commit the batch
      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Campaign "${campaign['title']}" deleted successfully'),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      print('Error deleting campaign: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting campaign: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  // NEW FUNCTION: Build a section for influencers to create posts
  Widget _buildInfluencerActionSection(
      Map<String, dynamic> campaign, String campaignId) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty || _accountType.toLowerCase() != 'influencer') {
      return const SizedBox.shrink();
    }

    // Get this influencer's bid data from the campaign
    final influencerBids = Map<String, Map<String, dynamic>>.from(
        (campaign['influencerBids'] ?? {}).map((key, value) =>
            MapEntry(key, Map<String, dynamic>.from(value ?? {}))));

    // Check if this influencer has a bid with 'in_progress' status
    final bidData = influencerBids[userId];
    final status = bidData?['status']?.toString() ?? '';
    final postCreated = bidData?['postCreated'] == true;

    // Only show post section if the bid is in progress (payment received)
    if (status != 'in_progress' || bidData == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        border: Border(
          top: BorderSide(color: Colors.purple.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!postCreated) ...[
            Row(
              children: [
                Icon(Icons.camera_alt, color: Colors.purple.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ready to create your campaign post?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Share this product with your followers to complete your campaign!',
              style: TextStyle(
                color: Colors.purple.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _createCampaignPost(campaignId, userId),
                icon: const Icon(Icons.add_photo_alternate, size: 18),
                label: const Text('Create Post'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            // Post has been created, show success message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Campaign post created successfully! 🎉',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markCampaignAsCompleted(campaignId, userId),
                icon: const Icon(Icons.task_alt, size: 18),
                label: const Text('Mark Campaign as Completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfluencerBidsSection(
      Map<String, dynamic> campaign, String campaignId) {
    final influencerBids = Map<String, Map<String, dynamic>>.from(
        (campaign['influencerBids'] ?? {}).map((key, value) =>
            MapEntry(key, Map<String, dynamic>.from(value ?? {}))));

    if (influencerBids.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(
              top: BorderSide(color: Colors.grey.shade200, width: 1),
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Influencer Bids (${influencerBids.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                  fontSize: 14,
                ),
              ),
              if (_accountType.toLowerCase() == 'organization') ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Review & Pay',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ...influencerBids.entries.map((entry) {
          final influencerId = entry.key;
          final bidData = entry.value;
          final bid = bidData['bid']?.toString() ?? '0';
          final bidAmount = (bidData['bid'] as num?)?.toDouble() ?? 0.0;
          final description = bidData['description']?.toString() ?? '';
          final status = bidData['status']?.toString() ?? 'pending';
          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

          return FutureBuilder<String>(
            future: _getInfluencerUsername(influencerId),
            builder: (context, snapshot) {
              final username = snapshot.data ?? 'Loading...';
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '\$$bid',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    _getBidStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getBidStatusColor(status),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getBidStatusIcon(status),
                                    size: 14,
                                    color: _getBidStatusColor(status),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getBidStatusText(status),
                                    style: TextStyle(
                                      color: _getBidStatusColor(status),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    // Show action buttons based on status and user type
                    if (_accountType.toLowerCase() == 'organization' &&
                        status == 'pending') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _declineInfluencerBid(
                                  campaignId, influencerId),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Decline'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade400,
                                side: BorderSide(color: Colors.red.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _acceptInfluencerBid(
                                  campaignId, influencerId),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Accept & Proceed'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade400,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (_accountType.toLowerCase() == 'organization' &&
                        status == 'escrow_pending') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.payment,
                                    color: Colors.orange.shade600, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Escrow payment required to proceed',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showEscrowPaymentDialog(
                                    campaignId, influencerId, bidAmount),
                                icon: const Icon(Icons.account_balance_wallet,
                                    size: 18),
                                label: Text(
                                    'Make Escrow Payment (\${bidAmount.toStringAsFixed(2)})'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (status == 'in_progress' &&
                        influencerId == userId) ...[
                      // Only the specific influencer who received payment can create posts and mark as completed
                      const SizedBox(height: 12),

                      // Check if post has been created
                      if (bidData['postCreated'] != true) ...[
                        // Show create post button first - only for the specific influencer
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.camera_alt,
                                      color: Colors.purple.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Payment received! Create your campaign post now',
                                      style: TextStyle(
                                        color: Colors.purple.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Show off this product to your followers!',
                                style: TextStyle(
                                  color: Colors.purple.shade600,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _createCampaignPost(
                                      campaignId, influencerId),
                                  icon: const Icon(Icons.add_photo_alternate,
                                      size: 18),
                                  label: const Text('Create Campaign Post'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        // Post has been created, show success indicator
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green.shade600, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Campaign post created successfully! 🎉',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Show mark as completed button only after post is created
                      if (bidData['postCreated'] == true) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _markCampaignAsCompleted(
                                campaignId, influencerId),
                            icon: const Icon(Icons.task_alt, size: 18),
                            label: const Text('Mark Campaign as Completed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ] else if (status == 'in_progress' &&
                        _accountType.toLowerCase() == 'influencer' &&
                        influencerId != userId) ...[
                      // Other influencers see that this one is in progress
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info,
                                color: Colors.blue.shade600, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'This influencer\'s campaign is in progress',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (status == 'completed') ...[
                      // Show completion info
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green.shade600, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Campaign work completed',
                              style: TextStyle(
                                color: Colors.green.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildBeautifulCampaignCard(
      Map<String, dynamic> campaign, String campaignId) {
    final status = _getCampaignStatus(campaign);
    final startDate = (campaign['startDate'] as Timestamp).toDate();
    final endDate = (campaign['endDate'] as Timestamp).toDate();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Get acceptance information
    final campaignOffer =
        Map<String, bool>.from(campaign['campaignOffer'] ?? {});
    final acceptedCount =
        campaignOffer.values.where((accepted) => accepted).length;
    final totalInvited = campaignOffer.length;

    // Check if current user is invited (for influencers)
    final isUserInvited = campaignOffer.containsKey(userId);
    final hasUserAccepted = campaignOffer[userId] ?? false;

    // Define card colors based on status and user type
    Color cardStartColor;
    Color cardEndColor;
    Color borderColor;

    switch (status) {
      case 'pending':
        cardStartColor = Colors.amber.shade50;
        cardEndColor = Colors.orange.shade50;
        borderColor = Colors.amber.shade200;
        break;
      case 'ongoing':
        cardStartColor = Colors.green.shade50;
        cardEndColor = Colors.teal.shade50;
        borderColor = Colors.green.shade200;
        break;
      case 'completed':
        cardStartColor = Colors.blue.shade50;
        cardEndColor = Colors.indigo.shade50;
        borderColor = Colors.blue.shade200;
        break;
      default:
        cardStartColor = Colors.grey.shade50;
        cardEndColor = Colors.grey.shade100;
        borderColor = Colors.grey.shade200;
    }

    // Special styling for influencer cards based on their acceptance status
    if (_accountType.toLowerCase() == 'influencer' && isUserInvited) {
      if (hasUserAccepted) {
        cardStartColor = Colors.purple.shade50;
        cardEndColor = Colors.deepPurple.shade50;
        borderColor = Colors.purple.shade200;
      } else {
        cardStartColor = Colors.yellow.shade50;
        cardEndColor = Colors.amber.shade50;
        borderColor = Colors.yellow.shade200;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardStartColor, cardEndColor],
        ),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        campaign['title'] ?? 'Untitled Campaign',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _getStatusColor(status),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(status),
                                size: 16,
                                color: _getStatusColor(status),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getStatusText(status),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Add analytics button in campaign header
                        if (_accountType.toLowerCase() == 'organization') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: InkWell(
                              onTap: () {
                                // Get the first influencer with in_progress or completed status
                                final influencerBids =
                                    Map<String, Map<String, dynamic>>.from(
                                        (campaign['influencerBids'] ?? {}).map(
                                            (key, value) => MapEntry(
                                                key,
                                                Map<String, dynamic>.from(
                                                    value ?? {}))));

                                final eligibleInfluencer = influencerBids
                                    .entries
                                    .where((entry) => [
                                          'in_progress',
                                          'completed'
                                        ].contains(entry.value['status']))
                                    .firstOrNull;

                                if (eligibleInfluencer != null) {
                                  _showAnalyticsScreen(
                                      campaignId, eligibleInfluencer.key);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'No analytics available yet. Campaign must be in progress.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.analytics,
                                      size: 14, color: Colors.blue.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Analytics',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        // Only show delete option for Organizations
                        if (_accountType.toLowerCase() == 'organization') ...[
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: Colors.grey.shade600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteCampaign(campaignId, campaign);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete,
                                        color: Colors.red.shade400, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Delete Campaign',
                                      style:
                                          TextStyle(color: Colors.red.shade400),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  campaign['description'] ?? 'No description',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.calendar_today,
                      '${startDate.day}/${startDate.month}/${startDate.year}',
                      Colors.blue.shade600,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      Icons.event,
                      '${endDate.day}/${endDate.month}/${endDate.year}',
                      Colors.green.shade600,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.payment,
                      campaign['paymentType']?.toString().toUpperCase() ??
                          'UNKNOWN',
                      Colors.deepPurple,
                    ),
                    const Spacer(),
                    _buildInfoChip(
                      Icons.people,
                      '$acceptedCount/$totalInvited Accepted',
                      acceptedCount == totalInvited
                          ? Colors.green.shade600
                          : Colors.orange.shade600,
                    ),
                  ],
                ),

                // Show action buttons for influencers
                if (_accountType.toLowerCase() == 'influencer' &&
                    isUserInvited &&
                    !hasUserAccepted) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _declineCampaignOffer(campaignId),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Decline'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade400,
                            side: BorderSide(color: Colors.red.shade400),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _acceptCampaignOffer(campaignId),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (_accountType.toLowerCase() == 'influencer' &&
                    hasUserAccepted) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'You have accepted this campaign',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Product section with improved styling
          FutureBuilder<Map<String, dynamic>?>(
            future: _getProductDetails(campaign['productId']),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final product = snapshot.data!;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    border: Border.symmetric(
                      horizontal: BorderSide(color: borderColor, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildProductImage(product),
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
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${(product['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                              style: TextStyle(
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  border: Border.symmetric(
                    horizontal: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    _buildProductImage(null),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Loading product details...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Add influencer post creation section for influencers
          if (_accountType.toLowerCase() == 'influencer')
            _buildInfluencerActionSection(campaign, campaignId),

          // Influencer bids section (only for organizations)
          if (_accountType.toLowerCase() == 'organization')
            _buildInfluencerBidsSection(campaign, campaignId),

          // Bottom border
          Container(
            height: 1,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getCampaignsStream(String status) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      return const Stream.empty();
    }

    if (_accountType.toLowerCase() == 'influencer') {
      // For influencers, get campaigns where they are invited
      return FirebaseFirestore.instance
          .collection('campaigns')
          .where('campaignOffer.$userId', isNotEqualTo: null)
          .snapshots();
    } else {
      // For organizations, get campaigns they created
      return FirebaseFirestore.instance
          .collection('campaigns')
          .where('createdBy', isEqualTo: userId)
          .snapshots();
    }
  }

  Widget _buildCampaignsTab(String status) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      return const Center(
          child: Text('You must be logged in to view campaigns'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _getCampaignsStream(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading campaigns...',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text('Error loading campaigns'),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          );
        }

        final allCampaigns = snapshot.data?.docs ?? [];

        // Filter campaigns based on status and sort by createdAt on client side
        final filteredCampaigns = allCampaigns.where((doc) {
          final campaign = doc.data() as Map<String, dynamic>;
          final campaignStatus = _getCampaignStatus(campaign);

          // For influencers, also filter pending based on whether they've responded
          if (_accountType.toLowerCase() == 'influencer' &&
              status == 'pending') {
            final campaignOffer =
                Map<String, bool>.from(campaign['campaignOffer'] ?? {});
            final hasUserResponded = campaignOffer.containsKey(userId) &&
                campaignOffer[userId] == true;
            // Only show in pending if they haven't accepted yet
            return campaignStatus == 'pending' && !hasUserResponded;
          }

          return campaignStatus == status;
        }).toList();

        // Sort by createdAt on client side (descending)
        filteredCampaigns.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime =
              (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bTime =
              (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          return bTime.compareTo(aTime);
        });

        if (filteredCampaigns.isEmpty) {
          return _buildEmptyState(status);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: filteredCampaigns.length,
          itemBuilder: (context, index) {
            final campaign =
                filteredCampaigns[index].data() as Map<String, dynamic>;
            return AnimatedContainer(
              duration: Duration(milliseconds: 300 + (index * 100)),
              child: _buildBeautifulCampaignCard(
                  campaign, filteredCampaigns[index].id),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String status) {
    String message;
    IconData icon;
    String actionText;

    if (_accountType.toLowerCase() == 'influencer') {
      switch (status) {
        case 'pending':
          message = 'No pending campaign invitations';
          icon = Icons.inbox;
          actionText = 'Waiting for campaign invitations';
          break;
        case 'ongoing':
          message = 'No active campaigns';
          icon = Icons.work_outline;
          actionText = 'Accept invitations to start campaigns';
          break;
        case 'completed':
          message = 'No completed campaigns yet';
          icon = Icons.check_circle_outline;
          actionText = 'Complete your campaigns';
          break;
        default:
          message = 'No campaigns found';
          icon = Icons.campaign;
          actionText = 'No campaigns available';
      }
    } else {
      switch (status) {
        case 'pending':
          message = 'No pending campaigns';
          icon = Icons.schedule;
          actionText = 'Create your first campaign';
          break;
        case 'ongoing':
          message = 'No active campaigns';
          icon = Icons.work_outline;
          actionText = 'Start a campaign today';
          break;
        case 'completed':
          message = 'No completed campaigns yet';
          icon = Icons.check_circle_outline;
          actionText = 'Complete your first campaign';
          break;
        default:
          message = 'No campaigns found';
          icon = Icons.campaign;
          actionText = 'Create a campaign';
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 60, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            actionText,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          if (status == 'pending' &&
              _accountType.toLowerCase() == 'organization') ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Uncomment the next lines when you have CreateCampaignScreen
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(
                //     builder: (context) => const CreateCampaignScreen(),
                //   ),
                // );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Create Campaign feature coming soon!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Campaign'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Add this Analytics Screen Widget at the end of the file
class AnalyticsScreen extends StatefulWidget {
  final String campaignId;
  final String influencerId;
  final String influencerName;
  final String campaignTitle;

  const AnalyticsScreen({
    Key? key,
    required this.campaignId,
    required this.influencerId,
    required this.influencerName,
    required this.campaignTitle,
  }) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Dummy analytics data
  final Map<String, dynamic> _analyticsData = {
    'impressions': 4287,
    'engagement': 842,
    'clicks': 356,
    'conversion': 28,
    'roi': 3.7,
    'likes': 523,
    'comments': 89,
    'shares': 127,
    'saves': 75,
    'timeSpent': 2.8, // minutes
  };

  // Daily engagement data for charts (7 days)
  final List<Map<String, dynamic>> _dailyData = [
    {'day': 'Mon', 'likes': 42, 'comments': 8, 'shares': 12},
    {'day': 'Tue', 'likes': 67, 'comments': 12, 'shares': 15},
    {'day': 'Wed', 'likes': 103, 'comments': 18, 'shares': 26},
    {'day': 'Thu', 'likes': 89, 'comments': 14, 'shares': 21},
    {'day': 'Fri', 'likes': 118, 'comments': 22, 'shares': 31},
    {'day': 'Sat', 'likes': 76, 'comments': 11, 'shares': 16},
    {'day': 'Sun', 'likes': 28, 'comments': 4, 'shares': 6},
  ];

  // Demographic data
  final List<Map<String, dynamic>> _demographicData = [
    {'age': '18-24', 'percentage': 32},
    {'age': '25-34', 'percentage': 41},
    {'age': '35-44', 'percentage': 18},
    {'age': '45-54', 'percentage': 7},
    {'age': '55+', 'percentage': 2},
  ];

  // Geographic data
  final List<Map<String, dynamic>> _geographicData = [
    {'region': 'North America', 'percentage': 43},
    {'region': 'Europe', 'percentage': 28},
    {'region': 'Asia', 'percentage': 18},
    {'region': 'South America', 'percentage': 7},
    {'region': 'Other', 'percentage': 4},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Simulate loading data
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Build a metric card for key stats
  Widget _buildMetricCard(
      String title, dynamic value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  // Build engagement chart
  Widget _buildEngagementChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Engagement',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 200),
              painter: ChartPainter(_dailyData),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Likes', Colors.blue),
              const SizedBox(width: 16),
              _buildLegendItem('Comments', Colors.green),
              const SizedBox(width: 16),
              _buildLegendItem('Shares', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  // Build legend item
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Build demographic chart
  Widget _buildDemographicChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Age Demographics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _demographicData.map((data) {
                      return Text(
                        '${data['age']}: ${data['percentage']}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: CustomPaint(
                    size: const Size(double.infinity, 200),
                    painter: PieChartPainter(_demographicData),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campaign Analytics',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.campaignTitle,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, color: Colors.purple[700], size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Influencer: ${widget.influencerName}',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Tab bar
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.purple[700],
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Colors.purple[700],
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Engagement'),
                    Tab(text: 'Demographics'),
                  ],
                ),
                const SizedBox(height: 16),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Overview tab
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              childAspectRatio: 1.5,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              children: [
                                _buildMetricCard(
                                    'Impressions',
                                    _analyticsData['impressions'],
                                    Icons.visibility,
                                    Colors.blue),
                                _buildMetricCard(
                                    'Engagement',
                                    '${(_analyticsData['engagement'] / _analyticsData['impressions'] * 100).toStringAsFixed(1)}%',
                                    Icons.thumb_up,
                                    Colors.green),
                                _buildMetricCard(
                                    'Click Rate',
                                    '${(_analyticsData['clicks'] / _analyticsData['impressions'] * 100).toStringAsFixed(1)}%',
                                    Icons.touch_app,
                                    Colors.amber),
                                _buildMetricCard(
                                    'ROI',
                                    '${_analyticsData['roi'].toStringAsFixed(1)}x',
                                    Icons.attach_money,
                                    Colors.purple),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildEngagementChart(),
                          ],
                        ),
                      ),
                      // Engagement tab
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              childAspectRatio: 1.5,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              children: [
                                _buildMetricCard(
                                    'Likes',
                                    _analyticsData['likes'],
                                    Icons.favorite,
                                    Colors.red),
                                _buildMetricCard(
                                    'Comments',
                                    _analyticsData['comments'],
                                    Icons.chat_bubble,
                                    Colors.blue),
                                _buildMetricCard(
                                    'Shares',
                                    _analyticsData['shares'],
                                    Icons.share,
                                    Colors.green),
                                _buildMetricCard(
                                    'Saves',
                                    _analyticsData['saves'],
                                    Icons.bookmark,
                                    Colors.amber),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Engagement Summary',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Total Engagement',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _analyticsData['engagement']
                                                  .toString(),
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Engagement Rate',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${(_analyticsData['engagement'] / _analyticsData['impressions'] * 100).toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Demographics tab
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildDemographicChart(),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Geographic Distribution',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ..._geographicData.map((data) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                data['region'],
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                '${data['percentage']}%',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          LinearProgressIndicator(
                                            value: data['percentage'] / 100,
                                            backgroundColor: Colors.grey[200],
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              _getRegionColor(data['region']),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Color _getRegionColor(String region) {
    switch (region) {
      case 'North America':
        return Colors.blue;
      case 'Europe':
        return Colors.green;
      case 'Asia':
        return Colors.orange;
      case 'South America':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// Custom chart painter for engagement
class ChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  ChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    // Find max values for scaling
    double maxLikes = 0;
    double maxComments = 0;
    double maxShares = 0;

    for (var item in data) {
      if (item['likes'] > maxLikes) maxLikes = item['likes'].toDouble();
      if (item['comments'] > maxComments)
        maxComments = item['comments'].toDouble();
      if (item['shares'] > maxShares) maxShares = item['shares'].toDouble();
    }

    final double maxValue =
        [maxLikes, maxComments, maxShares].reduce((a, b) => a > b ? a : b);

    // Calculate bar width
    final double barWidth = size.width / (data.length * 3 + 1);
    final double barSpacing = barWidth / 2;

    // Define paints
    final Paint likesPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final Paint commentsPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    final Paint sharesPaint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.fill;

    // Draw grid lines
    final Paint gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      double y = size.height - (size.height * i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw bars
    for (int i = 0; i < data.length; i++) {
      var item = data[i];

      // X position for group of bars
      double x = i * (barWidth * 3 + barSpacing) + barSpacing;

      // Likes bar
      double likesHeight = (item['likes'] / maxValue) * size.height;
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - likesHeight, barWidth, likesHeight),
        likesPaint,
      );

      // Comments bar
      double commentsHeight = (item['comments'] / maxValue) * size.height;
      canvas.drawRect(
        Rect.fromLTWH(x + barWidth, size.height - commentsHeight, barWidth,
            commentsHeight),
        commentsPaint,
      );

      // Shares bar
      double sharesHeight = (item['shares'] / maxValue) * size.height;
      canvas.drawRect(
        Rect.fromLTWH(x + barWidth * 2, size.height - sharesHeight, barWidth,
            sharesHeight),
        sharesPaint,
      );

      // Day label
      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: item['day'],
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + barWidth, size.height + 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom pie chart painter for demographics
class PieChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  PieChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Calculate total for percentages
    final double total =
        data.fold(0, (sum, item) => sum + item['percentage'] as double);

    // Define colors for each segment
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    // Draw pie segments
    double startAngle = 0;
    for (int i = 0; i < data.length; i++) {
      final percentage = data[i]['percentage'] / total;
      final sweepAngle = percentage * 2 * 3.14159; // Convert to radians

      paint.color = colors[i % colors.length];

      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.width / 3,
        ),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
