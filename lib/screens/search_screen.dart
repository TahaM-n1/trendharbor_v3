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
      // Search for users where username contains the query
      final usernameResults = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username', isLessThan: query.toLowerCase() + 'z')
          .limit(20)
          .get();

      final List<Map<String, dynamic>> results = [];

      for (var doc in usernameResults.docs) {
        // Skip the current user
        if (doc.id == _currentUserId) continue;

        final data = doc.data();
        results.add({
          'id': doc.id,
          'username': data['username'] ?? 'Unknown',
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'accountType': data['accountType'] ?? 'Personal',
          'isVerified': data['isVerified'] ?? false,
          'bio': data['bio'] ?? '',
        });
      }

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

  void _navigateToUserProfile(String userId) {
    context.go('/profile/$userId');
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

  @override
  Widget build(BuildContext context) {
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
          'Discover People',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for users...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search, color: Colors.deepPurple),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Search results count or suggestions header
            if (_searchQuery.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_searchResults.length} ${_searchResults.length == 1 ? 'result' : 'results'} for "$_searchQuery"',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                        ),
                      ),
                  ],
                ),
              )
            else
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.people, color: Colors.deepPurple, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'People from your campaigns',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const Spacer(),
                    if (_isLoadingSuggestions)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                        ),
                      ),
                  ],
                ),
              ),

            // Results list, suggestions, or empty state
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildSuggestionsView()
                  : _searchResults.isEmpty && !_isLoading
                      ? _buildNoResultsState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            return _buildUserListItem(user, index);
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _buildSuggestionsView() {
    if (_isLoadingSuggestions) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading suggestions...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_suggestedUsers.isEmpty) {
      return _buildEmptySearchState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _suggestedUsers.length,
      itemBuilder: (context, index) {
        final user = _suggestedUsers[index];
        return _buildUserListItem(user, index);
      },
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> user, int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      margin: const EdgeInsets.only(bottom: 12),
      child: _buildGradientCard(
        child: InkWell(
          onTap: () => _navigateToUserProfile(user['id']),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Profile image with hero animation
                Hero(
                  tag: 'profile-${user['id']}',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.deepPurple.shade100,
                      backgroundImage: user['profileImageUrl'] != null &&
                              user['profileImageUrl'].isNotEmpty
                          ? NetworkImage(user['profileImageUrl'])
                          : null,
                      child: user['profileImageUrl'] == null ||
                              user['profileImageUrl'].isEmpty
                          ? Text(
                              user['username'][0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // User info
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
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          user['accountType'] ?? 'Personal',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (user['bio'] != null && user['bio'].isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          user['bio'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Follow button
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple, Colors.purple.shade300],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      // Implement follow functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Following ${user['username']}'),
                          backgroundColor: Colors.green.shade400,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(80, 40),
                    ),
                    child: const Text(
                      'Follow',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.search,
              size: 60,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Search for people',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Find people to follow and collaborate with',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Text(
            'Start typing to discover new people',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.search_off,
              size: 60,
              color: Colors.orange.shade400,
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
          Text(
            'Try searching with different keywords',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
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
    );
  }
}
