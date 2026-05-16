import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';


// === Authentication and user bootstrap ======================================

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Signs the user in with Google and ensures a starter user doc exists.
  ///
  /// Returns the signed-in Firebase user, or null if the flow is cancelled.
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // The user canceled the sign-in
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      await ensureStarterUser(
        user: userCredential.user,
        email: googleUser.email,
        displayName: googleUser.displayName,
      );

      return userCredential.user;
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  /// Signs out of both Google and Firebase sessions.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Creates or updates a starter Firestore user document.
  ///
  /// Preserves existing fields when they already exist and timestamps updates.
  Future<void> ensureStarterUser({
    required User? user,
    String? email,
    String? displayName,
  }) async {
    if (user == null) {
      return;
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await userRef.get();
    final existing = snapshot.data() ?? <String, dynamic>{};

    await userRef.set({
      'uid': user.uid,
      'email': email ?? existing['email'] ?? '',
      'isProfileComplete': existing['isProfileComplete'] ?? false,
      'name': existing['name'] ?? displayName ?? '',
      'occupation': existing['occupation'] ?? '',
      'createdAt': existing['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetches user data only when the requested uid matches the current user.
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || currentUserId != uid) {
      return null;
    }

    final byId = await _firestore.collection('users').doc(uid).get();
    return byId.data();
  }

  /// Streams user data for the current user only.
  ///
  /// If the caller requests data for another uid, an empty stream is returned.
  Stream<Map<String, dynamic>?> userDataStream(String uid) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || currentUserId != uid) {
      return const Stream<Map<String, dynamic>?>.empty();
    }

    return _firestore.collection('users').doc(uid).snapshots().map((snap) {
      if (snap.exists) {
        return snap.data();
      }
      return null;
    });
  }

  /// Completes a user's profile and clears any temporary onboarding fields.
  Future<void> completeUserProfile({
    required String uid,
    required String name,
    required String occupation,
    required String organizationName,
    required String phoneNumber,
    String? gender,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'name': name.trim(),
      'occupation': occupation.trim(),
      'organizationName': organizationName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'gender': (gender ?? '').trim(),
      'isProfileComplete': true,
      'role': FieldValue.delete(),
      'roleDetail': FieldValue.delete(),
      'city': FieldValue.delete(),
      'primaryUse': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
