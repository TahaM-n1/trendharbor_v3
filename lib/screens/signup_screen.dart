import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  String? _selectedAccountType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Add a listener to convert uppercase to lowercase in real-time
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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _registerWithEmailAndPassword() async {
    // Validate form
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Force lowercase username one last time before submission
    final username = _usernameController.text.trim().toLowerCase();
    _usernameController.text = username;

    // Check password match
    if (_passwordController.text != _confirmPasswordController.text) {
      Fluttertoast.showToast(
        msg: 'Passwords do not match',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    // Check account type
    if (_selectedAccountType == null) {
      Fluttertoast.showToast(
        msg: 'Please select an account type',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    // Show loading
    setState(() {
      _isLoading = true;
    });

    try {
      // Check for username duplication
      final usernameQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          Fluttertoast.showToast(
            msg: 'Username already exists. Please choose a different username.',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      print("Creating user in Firebase Auth...");
      // Create user
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      print("User created in Firebase Auth. UID: ${userCredential.user?.uid}");

      // Save to Firestore immediately (don't delay this)
      try {
        print("Saving user data to Firestore...");
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user?.uid)
            .set({
          'email': _emailController.text.trim(),
          'username': username, // Use the lowercase username
          'accountType': _selectedAccountType,
          'createdAt': FieldValue.serverTimestamp(),
          'profileImageUrl': '', // Add default empty profileImageUrl
          'isVerified': false, // Add default verification status
        });
        print("User data saved to Firestore successfully!");

        // Store user data in shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        await prefs.setString('email', _emailController.text.trim());
        await prefs.setString('accountType', _selectedAccountType!);
        await prefs.setString('userId', userCredential.user?.uid ?? '');
        await prefs.setString('profileImageUrl', '');
        await prefs.setBool('isVerified', false);

        // Initialize the user service just like in the login screen
        if (context.mounted) {
          final userService = Provider.of<UserService>(context, listen: false);
          await userService.initUserData();
        }
      } catch (firestoreError) {
        print("Error saving to Firestore: $firestoreError");
        // Continue with navigation even if Firestore save fails
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show success toast
        Fluttertoast.showToast(
          msg: 'Registration successful!',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        // Navigate to home
        if (mounted) {
          context.go('/home');
        }
      }
    } on FirebaseAuthException catch (e) {
      // Error handling stays the same
      print('Firebase Auth Exception: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is badly formatted.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        case 'weak-password':
          errorMessage = 'The password is too weak.';
          break;
        default:
          errorMessage = 'An error occurred: ${e.code}';
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        Fluttertoast.showToast(
          msg: errorMessage,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      // General error handling stays the same
      print('General Exception during registration: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        Fluttertoast.showToast(
          msg: 'An unexpected error occurred: $e',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade300,
              Colors.blue.shade700,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 400), // Limit the width
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      // App Logo
                      Center(
                        child: Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Image.asset(
                            'assets/TH_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback if image loading fails
                              return Icon(
                                Icons.shopping_bag_outlined,
                                size: 60,
                                color: Colors.blue.shade700,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Title
                      Center(
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Username Input
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username (lowercase only)',
                          labelStyle: const TextStyle(color: Colors.white),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          // Add helper text to inform users
                          helperText: 'Lowercase letters, numbers, spaces and underscores only',
                          helperStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                        ),
                        style: const TextStyle(color: Colors.white),
                        // Force lowercase input
                        textCapitalization: TextCapitalization.none,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your username';
                          }
                          
                          // Check for uppercase letters
                          if (value != value.toLowerCase()) {
                            return 'Username must be lowercase only';
                          }
                          
                          // Updated regex to allow spaces
                          if (!RegExp(r'^[a-z0-9_ ]+$').hasMatch(value)) {
                            return 'Username can only contain lowercase letters, numbers, spaces, and underscores';
                          }
                          
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Account Type Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedAccountType,
                        items: const [
                          DropdownMenuItem(
                            value: 'Personal',
                            child: Text(
                              'Personal',
                              style: TextStyle(
                                  color: Colors.black), // Set text color
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Influencer',
                            child: Text(
                              'Influencer',
                              style: TextStyle(
                                  color: Colors.black), // Set text color
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Organization',
                            child: Text(
                              'Organization',
                              style: TextStyle(
                                  color: Colors.black), // Set text color
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedAccountType = value;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Account Type',
                          labelStyle: const TextStyle(color: Colors.white),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        dropdownColor:
                            Colors.white, // Set dropdown background color
                        style: const TextStyle(
                            color: Colors.black), // Set selected text color
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select an account type';
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
                          labelStyle: const TextStyle(color: Colors.white),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Password Input
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: Colors.white),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Confirm Password Input
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          labelStyle: const TextStyle(color: Colors.white),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      // Register Button
                      ElevatedButton(
                        onPressed:
                            _isLoading ? null : _registerWithEmailAndPassword,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue.shade700,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.blue),
                              )
                            : const Text(
                                'Register',
                                style: TextStyle(fontSize: 18),
                              ),
                      ),
                      const SizedBox(height: 16),
                      // Login Redirect
                      TextButton(
                        onPressed: () => context.go('/'),
                        child: const Text(
                          'Already have an account? Login',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
