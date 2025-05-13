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

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  String _accountType = 'personal';
  bool _isLoading = false;
  String? _currentUserId;
  Map<String, bool> _followingStatus = {};
  bool _isFollowingLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _getCurrentUser();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
          if (processedIds.contains(doc.id) || doc.id == _currentUserId) continue;
          
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
        return a['username'].toString().toLowerCase().compareTo(
            b['username'].toString().toLowerCase());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Users'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for users...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _searchResults.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onChanged: (value) {
                _searchUsers(value);
              },
            ),
          ),
        ),
      ),
      body: Column(
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
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
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
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> user) {
    final bool isFollowing = user['isFollowing'] ?? false;

    return InkWell(
      onTap: () => _navigateToUserProfile(user['id']),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: user['profileImageUrl'] != null &&
                      user['profileImageUrl'].isNotEmpty
                  ? NetworkImage(user['profileImageUrl'])
                  : null,
              child: user['profileImageUrl'] == null ||
                      user['profileImageUrl'].isEmpty
                  ? Text(
                      user['username'][0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    )
                  : null,
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
                          fontSize: 16,
                        ),
                      ),
                      if (user['isVerified'] == true) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 16,
                        ),
                      ],
                      if (isFollowing) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Following',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user['accountType'] ?? 'Personal',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  if (user['bio'] != null && user['bio'].isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      user['bio'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            OutlinedButton(
              onPressed: _isFollowingLoading
                  ? null
                  : () => _toggleFollow(user),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: isFollowing
                      ? Colors.grey.shade400
                      : Theme.of(context).primaryColor,
                ),
                backgroundColor: isFollowing
                    ? Colors.grey.shade100
                    : Colors.transparent,
                minimumSize: const Size(80, 36),
              ),
              child: _isFollowingLoading &&
                      _followingStatus.containsKey(user['id'])
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isFollowing ? 'Unfollow' : 'Follow'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Search for users',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find people to follow and collaborate with',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different keywords',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
