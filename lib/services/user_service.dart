import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class UserData {
  final String userId;
  final String username;
  final String email;
  final String accountType;
  final String profileImageUrl;
  final bool isVerified;

  UserData({
    required this.userId,
    required this.username,
    required this.email,
    required this.accountType,
    this.profileImageUrl = '',
    this.isVerified = false,
  });

  UserData copyWith({
    String? username,
    String? email,
    String? accountType,
    String? profileImageUrl,
    bool? isVerified,
  }) {
    return UserData(
      userId: this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      accountType: accountType ?? this.accountType,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  factory UserData.fromFirestore(DocumentSnapshot doc, User authUser) {
    return UserData(
      userId: authUser.uid,
      username: doc['username'] ?? '',
      email: authUser.email ?? '',
      accountType: doc['accountType'] ?? '',
      profileImageUrl: doc['profileImageUrl'] ?? '',
      isVerified: doc['isVerified'] ?? false,
    );
  }
}

class UserService extends ChangeNotifier {
  UserData? _currentUser;
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserData? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  // Safely get a field from a document snapshot with a default value
  dynamic _getFieldSafely(DocumentSnapshot doc, String fieldName, dynamic defaultValue) {
    if (!doc.exists) return defaultValue;

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return defaultValue;

    return data.containsKey(fieldName) ? data[fieldName] : defaultValue;
  }

  // Initialize user data when app starts
  Future<void> initUserData() async {
    setLoading(true);

    try {
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        _currentUser = null;
        setLoading(false);
        return;
      }

      // Try to get data from Firestore
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      String username = 'User';
      String email = firebaseUser.email ?? '';
      String accountType = 'Personal';
      String profileImageUrl = '';
      bool isVerified = false;

      // If document exists, get fields safely
      if (docSnapshot.exists) {
        username = _getFieldSafely(docSnapshot, 'username', 'User');
        email = _getFieldSafely(docSnapshot, 'email', firebaseUser.email ?? '');
        accountType = _getFieldSafely(docSnapshot, 'accountType', 'Personal');
        profileImageUrl = _getFieldSafely(docSnapshot, 'profileImageUrl', '');
        isVerified = _getFieldSafely(docSnapshot, 'isVerified', false);
      } else {
        // If the document doesn't exist, create it with default values
        await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .set({
              'username': username,
              'email': email,
              'accountType': accountType,
              'profileImageUrl': profileImageUrl,
              'isVerified': isVerified,
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      // Create user data object
      _currentUser = UserData(
        userId: firebaseUser.uid,
        username: username,
        email: email,
        accountType: accountType,
        profileImageUrl: profileImageUrl,
        isVerified: isVerified,
      );

      // Cache user data in shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      await prefs.setString('email', email);
      await prefs.setString('accountType', accountType);
      await prefs.setString('profileImageUrl', profileImageUrl);
      await prefs.setBool('isVerified', isVerified);

    } catch (e) {
      print('Error initializing user data: $e');
    } finally {
      setLoading(false);
    }
  }

  // Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Update profile image URL
  Future<bool> updateProfileImageUrl(String imageUrl) async {
    if (_currentUser == null) return false;

    try {
      _currentUser = _currentUser!.copyWith(profileImageUrl: imageUrl);
      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating profile image URL: $e');
      return false;
    }
  }

  // Refresh user data from Firestore
  Future<void> refreshUserData() async {
    try {
      if (_currentUser == null || _auth.currentUser == null) return;

      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();

      if (!docSnapshot.exists) {
        print('User document does not exist');
        return;
      }

      // Safely get fields with default values
      final username = _getFieldSafely(docSnapshot, 'username', 'User');
      final email = _getFieldSafely(docSnapshot, 'email', '');
      final accountType = _getFieldSafely(docSnapshot, 'accountType', 'Personal');
      final profileImageUrl = _getFieldSafely(docSnapshot, 'profileImageUrl', '');
      final isVerified = _getFieldSafely(docSnapshot, 'isVerified', false);

      // Update the current user object
      _currentUser = UserData(
        userId: _auth.currentUser!.uid,
        username: username,
        email: email,
        accountType: accountType,
        profileImageUrl: profileImageUrl,
        isVerified: isVerified,
      );

      notifyListeners();

      // Also update cached data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      await prefs.setString('email', email);
      await prefs.setString('accountType', accountType);
      await prefs.setString('profileImageUrl', profileImageUrl);
      await prefs.setBool('isVerified', isVerified);

    } catch (e) {
      print('Error refreshing user data: $e');
    }
  }

  // Update user data
  Future<bool> updateUserData({String? username, String? email}) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> updateData = {};

      if (username != null && username != _currentUser!.username) {
        updateData['username'] = username;
      }

      // Only update if we have data to update
      if (updateData.isNotEmpty) {
        await _firestore.collection('users').doc(_currentUser!.userId).update(updateData);

        // Update the current user object
        _currentUser = _currentUser!.copyWith(
          username: username ?? _currentUser!.username,
        );

        // Update SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        if (username != null) {
          await prefs.setString('username', username);
        }
      }

      // Handle email update through Firebase Auth if needed
      if (email != null && email != _currentUser!.email) {
        await _auth.currentUser?.updateEmail(email);
        _currentUser = _currentUser!.copyWith(email: email);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating user data: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateExtendedUserData({
    String? username,
    String? email,
    String? bio,
    String? accountType,
    bool? isVerified,
  }) async {
    if (currentUser == null) return;
    
    // Create a map with only the fields that need updating
    Map<String, dynamic> updates = {};
    if (username != null) updates['username'] = username;
    if (email != null) updates['email'] = email;
    if (bio != null) updates['bio'] = bio;
    if (accountType != null) updates['accountType'] = accountType;
    if (isVerified != null) updates['isVerified'] = isVerified;
    
    // Update the local currentUser object
    final updatedUser = UserData(
      userId: currentUser!.userId,
      username: username ?? currentUser!.username,
      email: email ?? currentUser!.email,
      profileImageUrl: currentUser!.profileImageUrl,
      accountType: accountType ?? currentUser!.accountType,
      isVerified: isVerified ?? currentUser!.isVerified,
    );
    
    // Update the current user object
    _currentUser = updatedUser;
    
    // Save to shared preferences
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('userId', updatedUser.userId);
    prefs.setString('username', updatedUser.username);
    prefs.setString('email', updatedUser.email);
    prefs.setString('accountType', updatedUser.accountType);
    prefs.setBool('isVerified', updatedUser.isVerified);
    if (updatedUser.profileImageUrl.isNotEmpty) {
      prefs.setString('profileImageUrl', updatedUser.profileImageUrl);
    }
    
    // Notify listeners that the user data has changed
    notifyListeners();
  }

  // Clear user data on logout
  void clearUserData() {
    _currentUser = null;
    notifyListeners();
  }

  // Setup auth state changes listener
  void setupAuthChangeListener() {
    print("Setting up auth change listener");

    // Listen for user state changes (sign in/out)
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      print("Auth state changed: user ${user?.uid ?? 'null'}");
      if (user == null) {
        // User signed out
        clearUserData();
      }
    });

    // Listen for user info changes (email updates, etc)
    FirebaseAuth.instance.userChanges().listen((User? user) async {
      print("User details changed: ${user?.email ?? 'null'} (current: ${_currentUser?.email ?? 'null'})");

      if (user != null && _currentUser != null) {
        // Check if email has changed from our stored version
        if (user.email != _currentUser!.email) {
          print('Email changed detected: ${_currentUser!.email} -> ${user.email}');

          // Update Firestore with new email
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'email': user.email});

            // Update our user object
            _currentUser = _currentUser!.copyWith(email: user.email ?? '');

            // Update SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('email', user.email ?? '');

            notifyListeners();
            print('Email updated in Firestore and local storage');
          } catch (e) {
            print('Failed to update email in Firestore: $e');
          }
        }

        // Also refresh user data periodically to catch any changes
        await refreshUserData();
      }
    });
  }

  // Check if user email has been verified and update accordingly
  Future<void> checkPendingEmailVerification() async {
    try {
      if (_currentUser == null || _auth.currentUser == null) return;

      // Force a token refresh to get the latest email
      await _auth.currentUser!.reload();

      // Get the current Firestore record
      final doc = await _firestore.collection('users').doc(_currentUser!.userId).get();

      if (doc.exists && doc.data()!.containsKey('pendingEmail')) {
        final pendingEmail = doc.data()!['pendingEmail'] as String?;

        // If the current Auth email matches the pending email, it means verification is complete
        if (pendingEmail != null && _auth.currentUser!.email == pendingEmail) {
          print('Email verification completed: ${_auth.currentUser!.email}');

          // Update Firestore by removing pendingEmail and updating email
          await _firestore.collection('users').doc(_currentUser!.userId).update({
            'email': _auth.currentUser!.email,
            'pendingEmail': FieldValue.delete(),
            'emailVerificationSent': FieldValue.delete()
          });

          // Update current user
          _currentUser = _currentUser!.copyWith(email: _auth.currentUser!.email ?? '');

          // Update SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('email', _auth.currentUser!.email ?? '');

          notifyListeners();
        }
      }
    } catch (e) {
      print('Error checking email verification: $e');
    }
  }
}