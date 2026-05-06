import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

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

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final byId = await _firestore.collection('users').doc(uid).get();
    if (byId.exists) {
      return byId.data();
    }

    final fallback = await _firestore
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (fallback.docs.isNotEmpty) {
      return fallback.docs.first.data();
    }
    return null;
  }

  Stream<Map<String, dynamic>?> userDataStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snap) {
      if (snap.exists) {
        return snap.data();
      }
      return null;
    });
  }

  Future<void> completeUserProfile({
    required String uid,
    required String name,
    required String occupation,
    required String organizationName,
    String? gender,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'name': name.trim(),
      'occupation': occupation.trim(),
      'organizationName': organizationName.trim(),
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
