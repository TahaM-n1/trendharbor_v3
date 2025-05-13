import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:trendharbor_v2/services/user_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = true;
  bool _isUpdating = false;
  String _accountType = '';
  String _userId = '';
  String? _profileImageUrl;
  bool _isVerified = false;
  bool _changePassword = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      await userService.refreshUserData();
      
      final user = userService.currentUser;
      if (user == null) {
        if (mounted) context.go('/');
        return;
      }
      
      // Get additional user data from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.userId)
          .get();
      
      if (mounted) {
        setState(() {
          _userId = user.userId;
          _usernameController.text = user.username;
          _emailController.text = user.email;
          _accountType = user.accountType;
          _profileImageUrl = user.profileImageUrl;
          _isVerified = user.isVerified;
          _bioController.text = userDoc.data()?['bio'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user data: $e')),
        );
      }
    }
  }
  
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isUpdating = true;
    });
    
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final currentEmail = userService.currentUser?.email ?? '';
      final newEmail = _emailController.text.trim();
      final newUsername = _usernameController.text.trim();
      final newBio = _bioController.text.trim();
      
      bool usernameChanged = false;
      bool emailChanged = false;
      bool passwordChanged = false;
      
      // Check if username needs to be updated
      if (newUsername != userService.currentUser?.username) {
        usernameChanged = true;
      }
      
      // Check if email needs to be updated
      if (newEmail != currentEmail) {
        if (_currentPasswordController.text.isEmpty) {
          throw Exception('Current password is required to update email');
        }
        emailChanged = true;
      }
      
      // Update Firestore first
      await FirebaseFirestore.instance.collection('users').doc(_userId).update({
        'username': newUsername,
        'bio': newBio,
        // Don't update email in Firestore yet - we'll do it after auth succeeds
      });
      
      // Re-authenticate user if email or password is changing
      if (emailChanged || _changePassword) {
        try {
          // Create credential
          final AuthCredential credential = EmailAuthProvider.credential(
            email: currentEmail,
            password: _currentPasswordController.text,
          );
          
          // Re-authenticate
          await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(credential);
        } catch (e) {
          throw Exception('Authentication failed: Invalid current password');
        }
      }
      
      // Update email if changed using verifyBeforeUpdateEmail
      if (emailChanged) {
        try {
          // Use verifyBeforeUpdateEmail instead of updateEmail
          await FirebaseAuth.instance.currentUser!.verifyBeforeUpdateEmail(newEmail);
          
          // Store pending email in Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_userId)
              .update({
                'pendingEmail': newEmail,
                'emailVerificationSent': FieldValue.serverTimestamp()
              });
          
          // Show success message for email verification
          if (mounted) {
            Fluttertoast.showToast(
              msg: 'Verification email sent to $newEmail. Please check your inbox and verify.',
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.CENTER,
              backgroundColor: Colors.blue,
              textColor: Colors.white,
            );
          }
        } catch (e) {
          // Handle email update errors
          if (e is FirebaseAuthException) {
            switch (e.code) {
              case 'email-already-in-use':
                throw Exception('This email is already in use by another account');
              case 'invalid-email':
                throw Exception('The email address is not valid');
              case 'requires-recent-login':
                throw Exception('Please log out and log back in before changing your email');
              default:
                throw Exception('Failed to request email change: ${e.message}');
            }
          } else {
            throw Exception('Failed to request email change: $e');
          }
        }
      }
      
      // Password change handling
      if (_changePassword && 
          _currentPasswordController.text.isNotEmpty &&
          _newPasswordController.text.isNotEmpty) {
        
        if (_newPasswordController.text != _confirmPasswordController.text) {
          throw Exception('New passwords do not match');
        }
        
        try {
          await FirebaseAuth.instance.currentUser!.updatePassword(_newPasswordController.text);
          passwordChanged = true;
        } catch (e) {
          throw Exception('Failed to update password: $e');
        }
      }
      
      // Update local cache in UserService
      await userService.updateExtendedUserData(
        username: newUsername, 
        email: emailChanged ? null : newEmail, // Only update email locally if not pending verification
        bio: newBio,
      );
      
      // Update shared preferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('username', newUsername);
      if (!emailChanged) {
        prefs.setString('email', newEmail);
      }
      
      // Prepare success message
      String successMessage = '';
      if (usernameChanged) successMessage += 'Username updated. ';
      if (emailChanged) successMessage += 'Email verification sent. ';
      if (passwordChanged) successMessage += 'Password updated. ';
      
      if (successMessage.isEmpty) {
        successMessage = 'Profile updated successfully.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
        
        // Return to profile
        context.pop();
      }
    } catch (e) {
      print('Error updating profile: $e');
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account type (non-editable)
              Card(
                margin: const EdgeInsets.only(bottom: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.badge,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Type',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _accountType,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Tooltip(
                        message: 'Account type cannot be changed',
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Username Input
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email Input
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  helperText: 'Changing email requires your current password',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Bio
              TextFormField(
                controller: _bioController,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  prefixIcon: const Icon(Icons.info_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Change Password Option
              CheckboxListTile(
                title: const Text('Change Password'),
                value: _changePassword,
                onChanged: (value) {
                  setState(() {
                    _changePassword = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),

              // Current Password Input
              if (_changePassword || _emailController.text != FirebaseAuth.instance.currentUser?.email)
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                  ),
                  validator: (value) {
                    if (_changePassword || _emailController.text != FirebaseAuth.instance.currentUser?.email) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password';
                      }
                    }
                    return null;
                  },
                ),

              // New Password Input (only if changing password)
              if (_changePassword) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                  ),
                  validator: (value) {
                    if (_changePassword) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_reset),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                  ),
                  validator: (value) {
                    if (_changePassword) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: _isUpdating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.blue.shade700),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16),
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