// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/bottom_navbar.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _suggestedUsers = [];
  String _accountType = 'personal';
  bool _isLoading = false;
  bool _isLoadingSuggestions = true;
  String? _currentUserId;
  Map<String, bool> _followingStatus = {};
  bool _isFollowingLoading = false;

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
    _getCurrentUser();
    _loadSuggestedUsers();
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final user = auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accountType = prefs.getString('accountType') ?? 'personal';
    });
  }

  Future<void> _loadSuggestedUsers() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      // Get all campaigns created by the current user
      final campaignsSnapshot = await FirebaseFirestore.instance
          .collection('campaigns')
          .where('createdBy', isEqualTo: _currentUserId)
          .get();

      // Collect all invited influencer IDs
      Set<String> invitedInfluencerIds = {};
      for (var doc in campaignsSnapshot.docs) {
        final campaign = doc.data();
        final List<dynamic> invitedInfluencers =
            campaign['invitedInfluencers'] ?? [];
        for (String influencerId in invitedInfluencers) {
          invitedInfluencerIds.add(influencerId);
        }
      }

      // Fetch user details for suggested users
      List<Map<String, dynamic>> suggestions = [];
      if (invitedInfluencerIds.isNotEmpty) {
        // Split into batches of 10 (Firestore whereIn limit)
        final batches = <List<String>>[];
        final List<String> influencerIdsList = invitedInfluencerIds.toList();

        for (int i = 0; i < influencerIdsList.length; i += 10) {
          final end = (i + 10 < influencerIdsList.length)
              ? i + 10
              : influencerIdsList.length;
          batches.add(influencerIdsList.sublist(i, end));
        }

        for (var batch in batches) {
          final usersSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          for (var doc in usersSnapshot.docs) {
            final data = doc.data();
            suggestions.add({
              'id': doc.id,
              'username': data['username'] ?? 'Unknown',
              'profileImageUrl': data['profileImageUrl'] ?? '',
              'accountType': data['accountType'] ?? 'Personal',
              'isVerified': data['isVerified'] ?? false,
              'bio': data['bio'] ?? '',
            });
          }
        }
      }

      setState(() {
        _suggestedUsers = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      print('Error loading suggested users: $e');
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchQuery = query;
    });

    try {
      // Convert query to lowercase for case-insensitive search
      final String lowercaseQuery = query.toLowerCase();

      // Use a combination approach for case-insensitive search
      // Step 1: Get users by lowercase username
      final usernameResults = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('username')
          .startAt([lowercaseQuery])
          .endAt([lowercaseQuery + '\uf8ff'])
          .limit(20)
          .get();

      // Step 2: Also try to get users by display name if you store it separately
      final displayNameResults = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('displayName')
          .startAt([lowercaseQuery])
          .endAt([lowercaseQuery + '\uf8ff'])
          .limit(20)
          .get();

      // Combine the results, removing duplicates
      final Set<String> processedIds = {};
      final List<Map<String, dynamic>> results = [];

      // Process both result sets
      for (final snapshot in [usernameResults, displayNameResults]) {
        for (var doc in snapshot.docs) {
          // Skip if already processed or is current user
          if (processedIds.contains(doc.id) || doc.id == _currentUserId)
            continue;

          processedIds.add(doc.id);
          final data = doc.data();
          final userId = doc.id;
          final username = data['username'] ?? 'Unknown';

          // Extra check: manual case-insensitive filtering to ensure accuracy
          if (username.toLowerCase().contains(lowercaseQuery)) {
            bool isFollowing = await _checkIfFollowing(userId);
            _followingStatus[userId] = isFollowing;

            results.add({
              'id': userId,
              'username': username,
              'profileImageUrl': data['profileImageUrl'] ?? '',
              'accountType': data['accountType'] ?? 'Personal',
              'isVerified': data['isVerified'] ?? false,
              'bio': data['bio'] ?? '',
              'isFollowing': isFollowing,
            });
          }
        }
      }

      // Sort with followed users at top, then alphabetically
      results.sort((a, b) {
        if (a['isFollowing'] && !b['isFollowing']) return -1;
        if (!a['isFollowing'] && b['isFollowing']) return 1;
        return a['username']
            .toString()
            .toLowerCase()
            .compareTo(b['username'].toString().toLowerCase());
      });

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkIfFollowing(String userId) async {
    if (_currentUserId == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('following')
          .doc(_currentUserId)
          .collection('userFollowing')
          .doc(userId)
          .get();

      return doc.exists;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> user) async {
    if (_currentUserId == null || _isFollowingLoading) return;

    final userId = user['id'];
    final isCurrentlyFollowing = _followingStatus[userId] ?? false;

    setState(() {
      _isFollowingLoading = true;
    });

    try {
      if (isCurrentlyFollowing) {
        await FirebaseFirestore.instance
            .collection('following')
            .doc(_currentUserId)
            .collection('userFollowing')
            .doc(userId)
            .delete();

        await FirebaseFirestore.instance
            .collection('followers')
            .doc(userId)
            .collection('userFollowers')
            .doc(_currentUserId)
            .delete();

        _followingStatus[userId] = false;

        final updatedResults = _searchResults.map((result) {
          if (result['id'] == userId) {
            return {
              ...result,
              'isFollowing': false,
            };
          }
          return result;
        }).toList();

        updatedResults.sort((a, b) {
          if (a['isFollowing'] && !b['isFollowing']) return -1;
          if (!a['isFollowing'] && b['isFollowing']) return 1;
          return a['username'].toString().compareTo(b['username'].toString());
        });

        setState(() {
          _searchResults = updatedResults;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unfollowed ${user['username']}')),
          );
        }
      } else {
        await FirebaseFirestore.instance
            .collection('following')
            .doc(_currentUserId)
            .collection('userFollowing')
            .doc(userId)
            .set({
          'timestamp': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('followers')
            .doc(userId)
            .collection('userFollowers')
            .doc(_currentUserId)
            .set({
          'timestamp': FieldValue.serverTimestamp(),
        });

        _followingStatus[userId] = true;

        final updatedResults = _searchResults.map((result) {
          if (result['id'] == userId) {
            return {
              ...result,
              'isFollowing': true,
            };
          }
          return result;
        }).toList();

        updatedResults.sort((a, b) {
          if (a['isFollowing'] && !b['isFollowing']) return -1;
          if (!a['isFollowing'] && b['isFollowing']) return 1;
          return a['username'].toString().compareTo(b['username'].toString());
        });

        setState(() {
          _searchResults = updatedResults;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Following ${user['username']}')),
          );
        }
      }
    } catch (e) {
      print('Error toggling follow status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFollowingLoading = false;
        });
      }
    }
  }

  void _navigateToUserProfile(String userId) {
    context.go('/profile/$userId');
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Search',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for users...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey.shade600),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _searchResults.clear();
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onChanged: (value) {
                      _searchUsers(value);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              if (_searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${_searchResults.length} ${_searchResults.length == 1 ? 'result' : 'results'} for "$_searchQuery"',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (_isLoading)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: _searchQuery.isEmpty
                    ? _buildEmptySearchState()
                    : _searchResults.isEmpty && !_isLoading
                        ? _buildNoResultsState()
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return _buildUserListItem(user);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> user) {
    final bool isFollowing = user['isFollowing'] ?? false;

    return InkWell(
      onTap: () => _navigateToUserProfile(user['id']),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.blue.shade300,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.blue.shade50,
                backgroundImage: user['profileImageUrl'] != null &&
                        user['profileImageUrl'].isNotEmpty
                    ? NetworkImage(user['profileImageUrl'])
                    : null,
                child: user['profileImageUrl'] == null ||
                        user['profileImageUrl'].isEmpty
                    ? Text(
                        user['username'][0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user['username'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      if (user['isVerified'] == true) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.verified,
                          color: Colors.blue.shade700,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user['accountType'] ?? 'User',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _isFollowingLoading ? null : () => _toggleFollow(user),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? Colors.white : Colors.blue.shade700,
                foregroundColor: isFollowing ? Colors.grey.shade800 : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isFollowing ? Colors.grey.shade300 : Colors.blue.shade700,
                  ),
                ),
                minimumSize: const Size(80, 36),
              ),
              child: _isFollowingLoading &&
                      _followingStatus.containsKey(user['id'])
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isFollowing ? Colors.blue.shade700 : Colors.white,
                        ),
                      ),
                    )
                  : Text(isFollowing ? 'Unfollow' : 'Follow'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 120),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search,
                  size: 64,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Find People',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Search for users to follow and connect with',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 120),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_outlined,
                  size: 64,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No users found',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Try searching with different keywords',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Tip: Try searching by username',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
