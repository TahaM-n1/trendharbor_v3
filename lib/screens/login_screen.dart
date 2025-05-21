import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:trendharbor_v2/services/user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Check if user is already logged in
    _checkCurrentUser();
    
    // Add listener to convert username/email to lowercase
    _emailController.addListener(() {
      final text = _emailController.text;
      final lowercaseText = text.toLowerCase();
      
      // Only update if there's a difference to avoid infinite loop
      if (text != lowercaseText) {
        // Remember cursor position
        final cursorPos = _emailController.selection.baseOffset;
        
        // Replace the text with lowercase version
        _emailController.value = TextEditingValue(
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
    super.dispose();
  }

  Future<void> _checkCurrentUser() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // User is already logged in, fetch user data and navigate to home
      await _fetchAndStoreUserData(currentUser.uid);
      if (mounted) {
        context.go('/home');
      }
    }
  }

  Future<void> _fetchAndStoreUserData(String uid) async {
    try {
      // Fetch user data from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        // Store user data in shared preferences for easy access
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', userDoc['username'] ?? '');
        await prefs.setString('accountType', userDoc['accountType'] ?? '');
        await prefs.setString('userId', uid);

        print('User data stored in preferences: ${userDoc['username']} - ${userDoc['accountType']}');
      } else {
        print('User document does not exist in Firestore');
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Future<void> _loginWithEmailOrUsername() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter both username/email and password',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Make sure input is lowercase before proceeding
      String input = _emailController.text.trim().toLowerCase();
      _emailController.text = input;  // Update controller with lowercase value
      String email;
      String? uid;

      // Check if the input is an email or username
      if (RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(input)) {
        email = input; // Input is an email
      } else {
        // Input is a username, retrieve the associated email from Firestore
        final usernameQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: input)
            .get();

        if (usernameQuery.docs.isEmpty) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'No user found for that username.',
          );
        }

        email = usernameQuery.docs.first['email'];
        uid = usernameQuery.docs.first.id;
      }

      // Proceed with Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // Get the user ID from the authentication result if not already fetched
      uid = uid ?? userCredential.user?.uid;

      if (uid != null) {
        // Fetch and store user data before navigation
        await _fetchAndStoreUserData(uid);
      }

      // After successful login, initialize the user data service
      final userService = Provider.of<UserService>(context, listen: false);
      await userService.initUserData();

      if (mounted) {
        context.go('/home'); // Navigate to the home screen on successful login
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found for that email or username.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is badly formatted.';
          break;
        default:
          errorMessage = 'An error occurred: ${e.code}';
      }
      Fluttertoast.showToast(
        msg: errorMessage,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'An unexpected error occurred: ${e.toString()}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
                constraints: const BoxConstraints(maxWidth: 400), // Limit the width
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
                    // App Title / Welcome Text
                    Center(
                      child: Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Email Input
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Username or Email',
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
                      keyboardType: TextInputType.emailAddress,
                      // Force lowercase input
                      textCapitalization: TextCapitalization.none,
                    ),
                    const SizedBox(height: 16),
                    // Password Input
                    TextField(
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
                    ),
                    const SizedBox(height: 24),
                    // Login Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _loginWithEmailOrUsername,
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                    const SizedBox(height: 16),
                    // Forget Password
                    TextButton(
                      onPressed: () => context.go('/forget-password'),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    // Create Account
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      child: const Text(
                        'Create New Account',
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
    );
  }
}