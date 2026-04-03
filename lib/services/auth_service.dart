import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google and return the Firebase User
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // On web, use signInWithPopup directly with Firebase Auth
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        final userCredential = await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
      } else {
        // On mobile, use google_sign_in package
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null; // User cancelled

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        return userCredential.user;
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user document exists in Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return doc.data();
    }
    return null;
  }

  /// Stream real-time updates of the user document
  Stream<Map<String, dynamic>?> userDataStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) return doc.data();
      return null;
    });
  }

  /// Save user with role to Firestore
  Future<void> saveUser({
    required String uid,
    required String name,
    required String email,
    required String role,
    String? photoUrl,
  }) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = <String, dynamic>{
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'photoUrl': photoUrl ?? '',
      'isProfileComplete': role == 'customer' ? true : false,
    };
    // Only set createdAt on first creation
    if (!doc.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  /// Save worker profile data (now with optional geo location)
  Future<void> saveWorkerProfile({
    required String uid,
    required List<String> skills,
    required int experience,
    String? location,
    String? name,
    String? phone,
    String? description,
    double? latitude,
    double? longitude,
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;

    final workerData = <String, dynamic>{
      'uid': uid,
      'name': name ?? user?.displayName ?? '',
      'email': user?.email ?? '',
      'photoUrl': photoUrl ?? user?.photoURL ?? '',
      'phone': phone ?? '',
      'skills': skills,
      'serviceType': skills.isNotEmpty ? skills.first : '',
      'experience': experience,
      'location': location ?? '',
      'description': description ?? '',
      'rating': 0.0,
      'totalJobs': 0,
      'isAvailable': true,
      'isSubscribed': false,
      'status': 'none',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Add geo data if coordinates are provided
    if (latitude != null && longitude != null) {
      final geoFirePoint = GeoFirePoint(GeoPoint(latitude, longitude));
      workerData['position'] = geoFirePoint.data;
      workerData['latitude'] = latitude;
      workerData['longitude'] = longitude;
    }

    // Save to workers collection
    await _firestore
        .collection('workers')
        .doc(uid)
        .set(workerData, SetOptions(merge: true));

    // Mark profile as not yet complete in users collection
    await _firestore.collection('users').doc(uid).update({
      'isProfileComplete': false,
    });
  }

  /// Activate worker profile after completing registration
  Future<void> activateWorkerProfile({required String uid}) async {
    // Update workers collection
    await _firestore.collection('workers').doc(uid).update({
      'isSubscribed': true,
      'status': 'active',
    });

    // Update users collection
    await _firestore.collection('users').doc(uid).update({
      'isProfileComplete': true,
    });
  }

  /// Get worker profile data
  Future<Map<String, dynamic>?> getWorkerData(String uid) async {
    final doc = await _firestore.collection('workers').doc(uid).get();
    if (doc.exists) {
      return doc.data();
    }
    return null;
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
