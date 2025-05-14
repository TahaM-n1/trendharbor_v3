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
  String _selectedAccountType = '';
  bool _accountTypeChanged = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    // Add listener to convert username to lowercase
    _usernameController.addListener(() {
      final text = _usernameController.text;
      final lowercaseText = text.toLowerCase();

      // Only update if there's a difference to avoid infinite loop
      if (text != lowercaseText) {
        // Remember cursor position
        final cursorPos = _usernameController.selection.baseOffset;

        // Replace the text with lowercase version
        _usernameController.value = TextEditingValue(
          text: lowercaseText,
          selection: TextSelection.collapsed(
            offset: cursorPos > 0 ? cursorPos : 0,
          ),
        );
      }
    });
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
          _selectedAccountType = user.accountType;
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
      final newUsername = _usernameController.text.trim().toLowerCase();
      _usernameController.text = newUsername;
      final newBio = _bioController.text.trim();

      bool usernameChanged = false;
      bool emailChanged = false;
      bool passwordChanged = false;
      bool accountTypeChanged = _accountType != _selectedAccountType;

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
        if (accountTypeChanged) 'accountType': _selectedAccountType,
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
        accountType: accountTypeChanged ? _selectedAccountType : null,
      );

      // Update shared preferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('username', newUsername);
      if (!emailChanged) {
        prefs.setString('email', newEmail);
      }
      if (accountTypeChanged) {
        prefs.setString('accountType', _selectedAccountType);
      }

      // Prepare success message
      String successMessage = '';
      if (usernameChanged) successMessage += 'Username updated. ';
      if (emailChanged) successMessage += 'Email verification sent. ';
      if (passwordChanged) successMessage += 'Password updated. ';
      if (accountTypeChanged) successMessage += 'Account type updated. ';
      
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
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.blue.shade700)),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600), // Limit width on large screens
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile header with avatar
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                              ? NetworkImage(_profileImageUrl!)
                              : null,
                          child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                              ? Text(
                                  _usernameController.text.isNotEmpty ? _usernameController.text[0].toUpperCase() : '?',
                                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        if (_isVerified)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Verified Account',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Section title
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Account Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),

                  // Account Type Card (Organization or Personal/Influencer)
                  if (_accountType.toLowerCase() == 'organization')
                    _buildAccountTypeCard(isEditable: false)
                  else
                    _buildAccountTypeCard(isEditable: true),

                  const SizedBox(height: 16),
                  
                  // Username Input - styled card
                  _buildInputCard(
                    title: 'Username',
                    icon: Icons.person,
                    iconColor: Colors.indigo.shade700,
                    cardColor: Colors.indigo.shade50,
                    borderColor: Colors.indigo.shade200,
                    child: TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username (lowercase only)',
                        labelStyle: TextStyle(color: Colors.indigo.shade700),
                        prefixIcon: Icon(Icons.person, color: Colors.indigo.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.indigo.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.indigo.shade400, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.indigo.shade200),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        helperText: 'Lowercase letters, numbers, spaces, and underscores only',
                        helperStyle: TextStyle(color: Colors.indigo.shade300),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      textCapitalization: TextCapitalization.none,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your username';
                        }
                        
                        if (value != value.toLowerCase()) {
                          return 'Username must be lowercase only';
                        }
                        
                        if (!RegExp(r'^[a-z0-9_ ]+$').hasMatch(value)) {
                          return 'Username can only contain lowercase letters, numbers, spaces, and underscores';
                        }
                        
                        return null;
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Email Input - styled card
                  _buildInputCard(
                    title: 'Contact Information',
                    icon: Icons.email,
                    iconColor: Colors.teal.shade700,
                    cardColor: Colors.teal.shade50,
                    borderColor: Colors.teal.shade200,
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.teal.shade700),
                        prefixIcon: Icon(Icons.email, color: Colors.teal.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal.shade200),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        helperText: 'Changing email requires your current password',
                        helperStyle: TextStyle(color: Colors.teal.shade300),
                        fillColor: Colors.white,
                        filled: true,
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
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Bio - styled card
                  _buildInputCard(
                    title: 'Personal Information',
                    icon: Icons.info_outline,
                    iconColor: Colors.amber.shade900,
                    cardColor: Colors.amber.shade50,
                    borderColor: Colors.amber.shade200,
                    child: TextFormField(
                      controller: _bioController,
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        labelStyle: TextStyle(color: Colors.amber.shade900),
                        prefixIcon: Icon(Icons.info_outline, color: Colors.amber.shade700),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.amber.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.amber.shade700, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.amber.shade200),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      maxLines: 3,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Password Section Title
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Security Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  
                  // Change Password Option - styled card
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.purple.shade200),
                    ),
                    color: Colors.purple.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.security, color: Colors.purple.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Password Settings',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            title: const Text('Change Password'),
                            subtitle: const Text('Update your account password'),
                            value: _changePassword,
                            onChanged: (value) {
                              setState(() {
                                _changePassword = value ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            activeColor: Colors.purple.shade700,
                          ),
                          
                          if (_changePassword || _emailController.text != FirebaseAuth.instance.currentUser?.email) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Current Password',
                                labelStyle: TextStyle(color: Colors.purple.shade700),
                                prefixIcon: Icon(Icons.lock, color: Colors.purple.shade400),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.purple.shade200),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 16,
                                ),
                                fillColor: Colors.white,
                                filled: true,
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
                          ],
                          
                          if (_changePassword) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                labelStyle: TextStyle(color: Colors.purple.shade700),
                                prefixIcon: Icon(Icons.lock_outline, color: Colors.purple.shade400),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.purple.shade200),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 16,
                                ),
                                fillColor: Colors.white,
                                filled: true,
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
                                labelStyle: TextStyle(color: Colors.purple.shade700),
                                prefixIcon: Icon(Icons.lock_reset, color: Colors.purple.shade400),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.purple.shade200),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 16,
                                ),
                                fillColor: Colors.white,
                                filled: true,
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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade200.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isUpdating ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        elevation: 0,
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
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        side: BorderSide(color: Colors.blue.shade700, width: 1.5),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method for account type card
  Widget _buildAccountTypeCard({required bool isEditable}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isEditable
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.badge, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Account Type',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedAccountType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Personal',
                        child: Text('Personal'),
                      ),
                      DropdownMenuItem(
                        value: 'Influencer',
                        child: Text('Influencer'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedAccountType = value;
                          _accountTypeChanged = _selectedAccountType != _accountType;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You can switch between Personal and Influencer accounts only',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Tooltip(
                    message: 'Organization accounts cannot change account type',
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade900),
                          const SizedBox(width: 4),
                          Text(
                            'Organization account',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Helper method for input cards
  Widget _buildInputCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color cardColor,
    required Color borderColor,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}