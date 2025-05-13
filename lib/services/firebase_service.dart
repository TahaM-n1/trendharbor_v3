import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// Custom user model that combines Auth and Firestore data
class AppUser {
  final String uid;
  final String email;
  final String accountType;
  final String? profileImageUrl;
  final bool emailVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.accountType,
    this.profileImageUrl,
    required this.emailVerified,
    this.createdAt,
    this.updatedAt,
  });

  // Convert Firestore document to AppUser
  factory AppUser.fromFirestore(DocumentSnapshot doc, User authUser) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: authUser.uid,
      email: authUser.email ?? data['email'] ?? '',
      accountType: data['accountType'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      emailVerified: authUser.emailVerified,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class FirebaseService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  // Auth Methods
  static Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String accountType,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user!.sendEmailVerification();
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  static Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Firestore Methods
  static Future<void> saveUserData({
    required String uid,
    required String email,
    required String accountType,
    String? profileImageUrl,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'accountType': accountType,
      'profileImageUrl': profileImageUrl,
      'emailVerified': false,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  // Storage Methods
  static Future<String> uploadProfileImage({
    required String uid,
    required XFile image,
  }) async {
    final ref = _storage.ref().child('profile_images/$uid.jpg');
    await ref.putData(await image.readAsBytes());
    return await ref.getDownloadURL();
  }

  static Future<AppUser?> getCurrentUser() async {
    final authUser = _auth.currentUser;
    if (authUser == null) return null;
    
    final doc = await _firestore.collection('users').doc(authUser.uid).get();
    return doc.exists ? AppUser.fromFirestore(doc, authUser) : null;
  }

  static Future<void> updateProfileImage(String uid, XFile image) async {
    final url = await uploadProfileImage(uid: uid, image: image);
    await _firestore.collection('users').doc(uid).update({
      'profileImageUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}