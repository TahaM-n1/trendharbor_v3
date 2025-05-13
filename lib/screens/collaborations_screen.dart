import 'package:flutter/material.dart';
import '../widgets/bottom_navbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CollaborationsScreen extends StatefulWidget {
  const CollaborationsScreen({super.key});

  @override
  State<CollaborationsScreen> createState() => _CollaborationsScreenState();
}

class _CollaborationsScreenState extends State<CollaborationsScreen> {
  String _accountType = 'personal';
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _accountType = prefs.getString('accountType') ?? 'personal';
      });
    }
  }

  Future<void> _showSearchCollaborationsDialog(BuildContext context) async {
    final TextEditingController searchController = TextEditingController();
    
    final String targetAccountType = _accountType == 'Influencer' ? 'Organization' : 'Influencer';
    
    List<Map<String, dynamic>> allAccounts = [];
    List<Map<String, dynamic>> filteredAccounts = [];
    
    bool isLoading = true;
    String? errorMessage;
    
    void searchAccounts(String query) {
      if (query.isEmpty) {
        filteredAccounts = List.from(allAccounts);
      } else {
        filteredAccounts = allAccounts
          .where((account) => 
            account['username'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
      }
    }
    
    try {
      final accountsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('accountType', isEqualTo: targetAccountType)
        .limit(50)
        .get();
      
      allAccounts = accountsSnapshot.docs
        .map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'username': data['username'] ?? 'Unknown',
            'profileImageUrl': data.containsKey('profileImageUrl') ? data['profileImageUrl'] : '',
            'accountType': data['accountType'] ?? targetAccountType,
          };
        })
        .toList();
      
      filteredAccounts = List.from(allAccounts);
      isLoading = false;
    } catch (e) {
      print('Error loading accounts: $e');
      errorMessage = 'Error loading accounts: $e';
      isLoading = false;
    }
    
    if (!context.mounted) return;
    
    Map<String, dynamic>? selectedAccount;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Find ${targetAccountType}s'),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for ${targetAccountType.toLowerCase()}s...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchAccounts(value);
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    
                    Expanded(
                      child: isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : errorMessage != null
                          ? Center(child: Text(errorMessage!))
                          : filteredAccounts.isEmpty
                            ? Center(child: Text('No ${targetAccountType.toLowerCase()}s found'))
                            : ListView.builder(
                                itemCount: filteredAccounts.length,
                                itemBuilder: (context, index) {
                                  final account = filteredAccounts[index];
                                  final bool isSelected = selectedAccount != null && 
                                                         selectedAccount!['id'] == account['id'];
                                  
                                  return ListTile(
                                    leading: _buildAccountAvatar(account),
                                    title: Text(account['username']),
                                    subtitle: Text(account['accountType']),
                                    selected: isSelected,
                                    tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
                                    onTap: () {
                                      setState(() {
                                        selectedAccount = isSelected ? null : account;
                                      });
                                    },
                                  );
                                },
                              ),
                    ),
                    
                    if (selectedAccount != null) ...[
                      const Divider(),
                      const SizedBox(height: 10),
                      Text(
                        'Create a Proposal for ${selectedAccount!['username']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Budget',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                          hintText: 'Enter proposed budget',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          selectedAccount!['budget'] = value;
                        },
                      ),
                      const SizedBox(height: 10),
                      
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                          hintText: 'Describe your collaboration proposal',
                        ),
                        maxLines: 3,
                        onChanged: (value) {
                          selectedAccount!['description'] = value;
                        },
                      ),
                      const SizedBox(height: 10),
                      
                      ElevatedButton(
                        onPressed: () {
                          _sendCollaborationProposal(
                            context: dialogContext, 
                            targetUserId: selectedAccount!['id'],
                            targetUsername: selectedAccount!['username'],
                            budget: selectedAccount!['budget'] ?? '',
                            description: selectedAccount!['description'] ?? '',
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Send Proposal'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ],
            );
          }
        );
      },
    ).then((_) {
      searchController.dispose();
    });
  }

  Widget _buildAccountAvatar(Map<String, dynamic> account) {
    if (account['profileImageUrl'] == null || account['profileImageUrl'].isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.blue.shade200,
        child: Text(
          account['username'].toString().isNotEmpty 
              ? account['username'].toString()[0].toUpperCase() 
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    
    return CircleAvatar(
      backgroundImage: account['profileImageUrl'].startsWith('assets/')
          ? AssetImage(account['profileImageUrl'])
          : NetworkImage(account['profileImageUrl']) as ImageProvider,
    );
  }

  Future<void> _sendCollaborationProposal({
    required BuildContext context,
    required String targetUserId,
    required String targetUsername,
    required String budget,
    required String description,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Get current user ID
      final User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) {
        throw Exception('You must be logged in to send a proposal');
      }
      
      // Get current user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final String currentUsername = userDoc.data()?['username'] ?? 'Unknown User';
      
      // Create a Timestamp for the current time (client-side)
      final Timestamp now = Timestamp.now();
      
      // Create collaboration proposal
      final proposalData = {
        'senderId': currentUser.uid,
        'senderUsername': currentUsername,
        'senderAccountType': _accountType,
        'recipientId': targetUserId,
        'recipientUsername': targetUsername,
        'recipientAccountType': _accountType == 'Influencer' ? 'Organization' : 'Influencer',
        'budget': budget,
        'description': description,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(), // This is fine outside of arrays
        'updatedAt': FieldValue.serverTimestamp(), // This is fine outside of arrays
        'messages': [
          {
            'senderId': currentUser.uid,
            'text': 'I would like to collaborate with you.',
            'timestamp': now, // Use client-side timestamp for array elements
          }
        ],
      };
      
      // Add to collaborations collection
      await FirebaseFirestore.instance
          .collection('collaborations')
          .add(proposalData);
      
      // Close loading dialog and previous dialog
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        Navigator.of(context).pop(); // Close search dialog
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proposal sent to $targetUsername'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending proposal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error sending proposal: $e');
    }
  }

  Future<void> _respondToProposal({
    required String collaborationId,
    required bool accept,
  }) async {
    try {
      final Timestamp now = Timestamp.now();
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      if (accept) {
        // When accepting a proposal, check if the current user is an organization
        final bool isOrganization = _accountType.toLowerCase() == 'organization';
        
        // If organization is accepting, set status to "escrow_pending"
        // If influencer is accepting, set status to "escrow_pending"
        // Either way, escrow payment is pending from organization
        final String newStatus = 'escrow_pending';
        final String message = 'I have accepted your collaboration proposal! Escrow payment is pending.';
        
        await FirebaseFirestore.instance
            .collection('collaborations')
            .doc(collaborationId)
            .update({
              'status': newStatus,
              'updatedAt': FieldValue.serverTimestamp(),
              'acceptedBy': currentUser.uid,
              'acceptedAt': FieldValue.serverTimestamp(),
              'messages': FieldValue.arrayUnion([
                {
                  'senderId': currentUser.uid,
                  'text': message,
                  'timestamp': now,
                }
              ])
            });
      } else {
        // Declining a proposal - no changes needed
        await FirebaseFirestore.instance
            .collection('collaborations')
            .doc(collaborationId)
            .update({
              'status': 'declined',
              'updatedAt': FieldValue.serverTimestamp(),
              'messages': FieldValue.arrayUnion([
                {
                  'senderId': currentUser.uid,
                  'text': 'I have declined your collaboration proposal.',
                  'timestamp': now,
                }
              ])
            });
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proposal ${accept ? 'accepted' : 'declined'}'),
            backgroundColor: accept ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error responding to proposal: $e');
    }
  }

  Future<void> _showCounterProposalDialog(
    BuildContext context, 
    String collaborationId,
    Map<String, dynamic> originalProposal,
  ) async {
    final TextEditingController budgetController = TextEditingController(text: originalProposal['budget']);
    final TextEditingController descriptionController = TextEditingController(text: originalProposal['description']);
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Counter Proposal'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: budgetController,
                  decoration: const InputDecoration(
                    labelText: 'Budget',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _submitCounterProposal(
                  collaborationId: collaborationId,
                  budget: budgetController.text,
                  description: descriptionController.text,
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Send Counter'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitCounterProposal({
    required String collaborationId,
    required String budget,
    required String description,
  }) async {
    try {
      final Timestamp now = Timestamp.now(); // Use client-side timestamp
      
      await FirebaseFirestore.instance
          .collection('collaborations')
          .doc(collaborationId)
          .update({
            'budget': budget,
            'description': description,
            'status': 'counter',
            'updatedAt': FieldValue.serverTimestamp(),
            'counterOfferedBy': FirebaseAuth.instance.currentUser?.uid,
            'messages': FieldValue.arrayUnion([
              {
                'senderId': FirebaseAuth.instance.currentUser?.uid,
                'text': 'I have sent you a counter proposal.',
                'timestamp': now, // Use client-side timestamp for array elements
              }
            ])
          });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Counter proposal sent'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error sending counter proposal: $e');
    }
  }

  Future<void> _showEscrowPaymentDialog(String collaborationId) async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Make Escrow Payment'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet, size: 60, color: Colors.blue),
              SizedBox(height: 16),
              Text(
                'This simulates an escrow payment for the collaboration.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
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
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _makeEscrowPayment(collaborationId);
              },
              child: const Text('Payment Done'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _makeEscrowPayment(String collaborationId) async {
    try {
      final Timestamp now = Timestamp.now();
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      await FirebaseFirestore.instance
          .collection('collaborations')
          .doc(collaborationId)
          .update({
            'status': 'in_progress',
            'updatedAt': FieldValue.serverTimestamp(),
            'escrowPaidBy': currentUser.uid,
            'escrowPaidAt': FieldValue.serverTimestamp(),
            'messages': FieldValue.arrayUnion([
              {
                'senderId': currentUser.uid,
                'text': 'I have made the escrow payment. The collaboration is now in progress.',
                'timestamp': now,
              }
            ])
          });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Escrow payment completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error making escrow payment: $e');
    }
  }



  
  Future<void> _markCollaborationAsCompleted(String collaborationId) async {
    try {
      final Timestamp now = Timestamp.now();
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      // Get the collaboration document
      final collaborationDoc = await FirebaseFirestore.instance
          .collection('collaborations')
          .doc(collaborationId)
          .get();
      
      final collabData = collaborationDoc.data() as Map<String, dynamic>?;
      if (collabData == null) return;
      
      // Check if current user is influencer or organization
      final bool isInfluencer = _accountType.toLowerCase() == 'influencer';
      
      // If influencer, set status to "pending_completion", otherwise set to "completed"
      final String newStatus = isInfluencer ? 'pending_completion' : 'completed';
      final String message = isInfluencer 
          ? 'I have marked this collaboration as completed. Awaiting confirmation.' 
          : 'I have marked this collaboration as completed.';
      
      // Set the appropriate fields based on user type
      final Map<String, dynamic> updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'messages': FieldValue.arrayUnion([
          {
            'senderId': currentUser.uid,
            'text': message,
            'timestamp': now,
          }
        ])
      };
      
      // If organization is completing, add completedAt field
      if (!isInfluencer) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      } else {
        // If influencer is completing, record who initiated completion
        updateData['completionRequestedBy'] = currentUser.uid;
        updateData['completionRequestedAt'] = FieldValue.serverTimestamp();
      }
      
      // Update the document
      await FirebaseFirestore.instance
          .collection('collaborations')
          .doc(collaborationId)
          .update(updateData);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isInfluencer 
                ? 'Completion request sent to organization' 
                : 'Collaboration marked as completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error marking collaboration as completed: $e');
    }
  }
  
  Future<void> _confirmCompletionRequest(String collaborationId) async {
    try {
      final Timestamp now = Timestamp.now();
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      await FirebaseFirestore.instance
          .collection('collaborations')
          .doc(collaborationId)
          .update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'completionConfirmedBy': currentUser.uid,
            'completionConfirmedAt': FieldValue.serverTimestamp(),
            'messages': FieldValue.arrayUnion([
              {
                'senderId': currentUser.uid,
                'text': 'I have confirmed the completion of this collaboration.',
                'timestamp': now,
              }
            ])
          });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collaboration marked as completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error confirming completion: $e');
    }
  }
  
  Future<void> _declineCompletionRequest(String collaborationId) async {
    try {
      final Timestamp now = Timestamp.now();
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      await FirebaseFirestore.instance
          .collection('collaborations')
          .doc(collaborationId)
          .update({
            'status': 'in_progress', // Reset status back to in_progress
            'updatedAt': FieldValue.serverTimestamp(),
            'messages': FieldValue.arrayUnion([
              {
                'senderId': currentUser.uid,
                'text': 'I have declined the completion request. The collaboration is still in progress.',
                'timestamp': now,
              }
            ])
          });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completion request declined'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error declining completion: $e');
    }
  }




  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Collaborations'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Ongoing'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingTab(),
            _buildOngoingTab(),
            _buildCompletedTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showSearchCollaborationsDialog(context),
          label: const Text('New Collaboration'),
          icon: const Icon(Icons.add),
        ),
        bottomNavigationBar: const BottomNavBar(),
      ),
    );
  }

  Widget _buildPendingTab() {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      return const Center(child: Text('You must be logged in to view collaborations'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('collaborations')
          .where('status', whereIn: ['pending', 'counter']) // Include counter offers
          .where('recipientId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, incomingSnapshot) {
        if (incomingSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('collaborations')
              .where('status', whereIn: ['pending', 'counter']) // Include counter offers
              .where('senderId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, outgoingSnapshot) {
            if (outgoingSnapshot.connectionState == ConnectionState.waiting && 
                incomingSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (incomingSnapshot.hasError) {
              print("Incoming error: ${incomingSnapshot.error}");
              return Center(child: Text('Error: ${incomingSnapshot.error}'));
            }
            
            if (outgoingSnapshot.hasError) {
              print("Outgoing error: ${outgoingSnapshot.error}");
              return Center(child: Text('Error: ${outgoingSnapshot.error}'));
            }
            
            final incomingDocs = incomingSnapshot.data?.docs ?? [];
            final outgoingDocs = outgoingSnapshot.data?.docs ?? [];
            
            // Combine both lists
            final List<QueryDocumentSnapshot> allCollaborations = [
              ...incomingDocs,
              ...outgoingDocs,
            ];
            
            // Sort combined list by createdAt
            allCollaborations.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              return bTime.compareTo(aTime); // Descending order
            });
            
            if (allCollaborations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hourglass_empty, size: 60, color: Colors.grey),
                    const SizedBox(height: 10),
                    const Text(
                      'No pending collaborations',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _showSearchCollaborationsDialog(context),
                      child: const Text('Find Collaborations'),
                    ),
                  ],
                ),
              );
            }
            
            return ListView.builder(
              itemCount: allCollaborations.length,
              itemBuilder: (context, index) {
                final collab = allCollaborations[index].data() as Map<String, dynamic>;
                final bool isIncoming = collab['recipientId'] == userId;
                final bool isCounterOffer = collab['status'] == 'counter';
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isIncoming ? 'From ${collab['senderUsername']}' : 'To ${collab['recipientUsername']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Chip(
                              label: Text(
                                isCounterOffer 
                                    ? 'Counter Offer' 
                                    : (isIncoming ? 'Incoming' : 'Outgoing'),
                                style: TextStyle(
                                  color: isCounterOffer 
                                      ? Colors.blue.shade700 
                                      : (isIncoming ? Colors.white : Colors.black),
                                ),
                              ),
                              backgroundColor: isCounterOffer 
                                  ? Colors.blue.shade100
                                  : (isIncoming ? Colors.green : Colors.amber),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Budget: \$${collab['budget']}'),
                        Text(
                          'Description: ${collab['description']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        // Show who made the counter offer
                        if (isCounterOffer && collab.containsKey('counterOfferedBy')) ...[
                          const SizedBox(height: 8),
                          Text(
                            collab['counterOfferedBy'] == userId 
                                ? 'You sent a counter offer' 
                                : 'Counter offer received',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.blue.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        
                        // Show action buttons for incoming proposals or counter offers
                        if ((isIncoming && !isCounterOffer) || 
                            (isCounterOffer && collab['counterOfferedBy'] != userId)) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => _respondToProposal(
                                  collaborationId: allCollaborations[index].id,
                                  accept: false,
                                ),
                                child: const Text('Decline'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => _showCounterProposalDialog(
                                  context,
                                  allCollaborations[index].id,
                                  collab,
                                ),
                                child: const Text('Counter'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _respondToProposal(
                                  collaborationId: allCollaborations[index].id,
                                  accept: true,
                                ),
                                child: const Text('Accept'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOngoingTab() {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      return const Center(child: Text('You must be logged in to view collaborations'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('collaborations')
          .where('status', whereIn: ['escrow_pending', 'in_progress', 'pending_completion'])
          .where('recipientId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, incomingSnapshot) {
        if (incomingSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('collaborations')
              .where('status', whereIn: ['escrow_pending', 'in_progress', 'pending_completion'])
              .where('senderId', isEqualTo: userId)
              .orderBy('updatedAt', descending: true)
              .snapshots(),
          builder: (context, outgoingSnapshot) {
            if (outgoingSnapshot.connectionState == ConnectionState.waiting && 
                incomingSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (incomingSnapshot.hasError || outgoingSnapshot.hasError) {
              return Center(child: Text('Error: ${incomingSnapshot.error ?? outgoingSnapshot.error}'));
            }
            
            final incomingDocs = incomingSnapshot.data?.docs ?? [];
            final outgoingDocs = outgoingSnapshot.data?.docs ?? [];
            
            // Combine both lists
            final List<QueryDocumentSnapshot> allCollaborations = [
              ...incomingDocs,
              ...outgoingDocs,
            ];
            
            if (allCollaborations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.work_outline, size: 60, color: Colors.grey),
                    const SizedBox(height: 10),
                    const Text(
                      'No active collaborations',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }
            
            return ListView.builder(
              itemCount: allCollaborations.length,
              itemBuilder: (context, index) {
                final collab = allCollaborations[index].data() as Map<String, dynamic>;
                final String partnerName = collab['recipientId'] == userId ? 
                    collab['senderUsername'] : collab['recipientUsername'];
                
                // Get the current status
                final String status = collab['status'] as String;
                
                // Define flags for the different statuses
                final bool isEscrowPending = status == 'escrow_pending';
                final bool isInProgress = status == 'in_progress';
                final bool isPendingCompletion = status == 'pending_completion';
                
                // Check if the current user is the organization who needs to pay
                final bool isOrganization = _accountType.toLowerCase() == 'organization';
                final bool isInfluencer = _accountType.toLowerCase() == 'influencer';
                
                // Determine if organization needs to pay
                final bool organizationNeedsToPayEscrow = isEscrowPending && isOrganization;
                
                // Check if user is organization and this is a completion request from influencer
                final bool isCompletionRequestToOrganization = isPendingCompletion && 
                                                           isOrganization; 
                                                           //&& collab['recipientId'] == userId;
                
                // Text and chip styling based on status
                String statusText = '';
                Color chipBackgroundColor;
                Color chipTextColor;
                Widget? chipIcon;
                
                // Set status text and chip styling
                if (isEscrowPending) {
                  statusText = 'Escrow Payment Pending';
                  chipBackgroundColor = Colors.orange.shade100;
                  chipTextColor = Colors.orange.shade900;
                  chipIcon = const Icon(Icons.payment, size: 16);
                } else if (isInProgress) {
                  statusText = 'In Progress';
                  chipBackgroundColor = Colors.green.shade100;
                  chipTextColor = Colors.green.shade900;
                  chipIcon = const Icon(Icons.work, size: 16);
                } else if (isPendingCompletion) {
                  statusText = 'Pending Completion';
                  chipBackgroundColor = Colors.amber.shade100;
                  chipTextColor = Colors.amber.shade900;
                  chipIcon = const Icon(Icons.check_circle_outline, size: 16);
                } else {
                  statusText = 'Unknown Status';
                  chipBackgroundColor = Colors.grey.shade200;
                  chipTextColor = Colors.grey.shade800;
                  chipIcon = null;
                }
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Collaborating with $partnerName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Chip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (chipIcon != null) ...[
                                    chipIcon,
                                    const SizedBox(width: 4),
                                  ],
                                  Text(statusText),
                                ],
                              ),
                              backgroundColor: chipBackgroundColor,
                              labelStyle: TextStyle(color: chipTextColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Budget: \$${collab['budget']}'),
                        Text('Description: ${collab['description']}'),
                        
                        // Show status-specific messages
                        if (isEscrowPending) ...[
                          const SizedBox(height: 12),
                          Text(
                            isOrganization 
                                ? 'Please make the escrow payment to proceed with the collaboration.' 
                                : 'Waiting for the organization to make the escrow payment.',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.blue,
                            ),
                          ),
                        ] else if (isInProgress) ...[
                          const SizedBox(height: 12),
                          Text(
                            isInfluencer 
                                ? 'Escrow payment received. You can proceed with your work.' 
                                : 'Escrow payment sent. Waiting for the influencer to complete their work.',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.blue,
                            ),
                          ),
                        ] else if (isPendingCompletion) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Influencer has marked this collaboration as completed.',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                // Show details or chat about the collaboration
                              },
                              child: const Text('Details'),
                            ),
                            const SizedBox(width: 8),
                            
                            // For organization that needs to pay escrow
                            if (organizationNeedsToPayEscrow) ...[
                              ElevatedButton(
                                onPressed: () => _showEscrowPaymentDialog(allCollaborations[index].id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                                child: const Text('Make Payment'),
                              ),
                            ] 
                            // For organization dealing with completion requests
                            else if (isCompletionRequestToOrganization) ...[
                              OutlinedButton(
                                onPressed: () => _declineCompletionRequest(allCollaborations[index].id),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Still in Progress'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _confirmCompletionRequest(allCollaborations[index].id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text('Confirm Completion'),
                              ),
                            ] 
                            // For regular in-progress collaborations
                            else if (isInProgress && !isPendingCompletion) ...[
                              ElevatedButton(
                                onPressed: () {
                                  _markCollaborationAsCompleted(allCollaborations[index].id);
                                },
                                child: const Text('Mark as Completed'),
                              ),
                            ]
                            // For influencers who have already sent completion requests
                            else if (isPendingCompletion) ...[
                              ElevatedButton(
                                onPressed: null, // Disabled button
                                style: ElevatedButton.styleFrom(
                                  disabledBackgroundColor: Colors.grey.shade300,
                                ),
                                child: const Text('Awaiting Confirmation'),
                              ),
                            ]
                            // For influencers waiting for escrow payment
                            else if (isEscrowPending && !isOrganization) ...[
                              ElevatedButton(
                                onPressed: null, // Disabled button
                                style: ElevatedButton.styleFrom(
                                  disabledBackgroundColor: Colors.grey.shade300,
                                ),
                                child: const Text('Awaiting Payment'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedTab() {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      return const Center(child: Text('You must be logged in to view collaborations'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('collaborations')
          .where('status', isEqualTo: 'completed') // Make sure this is explicit
          .where('recipientId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, incomingSnapshot) {
        if (incomingSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('collaborations')
              .where('status', isEqualTo: 'completed')
              .where('senderId', isEqualTo: userId)
              .orderBy('updatedAt', descending: true)
              .snapshots(),
          builder: (context, outgoingSnapshot) {
            if (outgoingSnapshot.connectionState == ConnectionState.waiting && 
                incomingSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (incomingSnapshot.hasError || outgoingSnapshot.hasError) {
              return Center(child: Text('Error: ${incomingSnapshot.error ?? outgoingSnapshot.error}'));
            }
            
            final incomingDocs = incomingSnapshot.data?.docs ?? [];
            final outgoingDocs = outgoingSnapshot.data?.docs ?? [];
            
            // Combine both lists
            final List<QueryDocumentSnapshot> allCollaborations = [
              ...incomingDocs,
              ...outgoingDocs,
            ];
            
            if (allCollaborations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 60, color: Colors.grey),
                    const SizedBox(height: 10),
                    const Text(
                      'No completed collaborations',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }
            
            return ListView.builder(
              itemCount: allCollaborations.length,
              itemBuilder: (context, index) {
                final collab = allCollaborations[index].data() as Map<String, dynamic>;
                final String partnerName = collab['recipientId'] == userId ? 
                    collab['senderUsername'] : collab['recipientUsername'];
                
                // Format the completion date
                final completedAt = collab['completedAt'] as Timestamp?;
                final completionDate = completedAt != null 
                    ? _formatTimestamp(completedAt)
                    : 'Unknown date';
                    
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Collaboration with $partnerName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Chip(
                              label: const Text('Completed'),
                              backgroundColor: Colors.green.shade100,
                              labelStyle: TextStyle(color: Colors.green.shade800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Budget: \$${collab['budget']}'),
                        Text(
                          'Description: ${collab['description']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Completed on: $completionDate',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                // Show collaboration details or history
                              },
                              child: const Text('View Details'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    
    if (now.difference(dateTime).inDays == 0) {
      // Today, show time
      return 'Today at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(dateTime).inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (now.difference(dateTime).inDays < 7) {
      // Within a week
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekdays[dateTime.weekday - 1];
    } else {
      // Earlier
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    }
  }
}