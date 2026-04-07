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

  /// Generates the user document ID as "Name_uid" for readability in Firestore console
  String _userDocId(String name, String uid) {
    final sanitized = name.trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '')
        .replaceAll(' ', '-');
    return '${sanitized}_$uid';
  }

  /// Finds the user document reference by querying on the uid field.
  /// Works for both old (uid-only) and new (Name_uid) document IDs.
  Future<DocumentReference?> _userDocRef(String uid) async {
    final snap = await _firestore
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first.reference;
    return null;
  }

  /// Generates the worker document ID as "Name_uid" format
  String _workerDocId(String name, String uid) {
    final sanitized = name.trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '')
        .replaceAll(' ', '-');
    return '${sanitized}_$uid';
  }

  /// Finds the worker document reference by querying on the uid field.
  /// Works for both old (uid-only) and new (Name_uid) document IDs.
  Future<DocumentReference?> _workerDocRef(String uid) async {
    final snap = await _firestore
        .collection('workers')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first.reference;
    return null;
  }

  /// Check if user document exists in Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final snap = await _firestore
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first.data();
    return null;
  }

  /// Stream real-time updates of the user document
  Stream<Map<String, dynamic>?> userDataStream(String uid) {
    return _firestore
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty ? snap.docs.first.data() : null);
  }

  /// Save user with role to Firestore
  Future<void> saveUser({
    required String uid,
    required String name,
    required String email,
    required String role,
    String? photoUrl,
  }) async {
    final existingRef = await _userDocRef(uid);
    final data = <String, dynamic>{
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'photoUrl': photoUrl ?? '',
      'isProfileComplete': role == 'customer' ? true : false,
    };
    if (existingRef != null) {
      await existingRef.set(data, SetOptions(merge: true));
    } else {
      // New user: create doc with Name_uid format
      data['createdAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection('users')
          .doc(_userDocId(name, uid))
          .set(data, SetOptions(merge: true));
    }
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

    // Save to workers collection using Name_uid format for new docs
    final existingRef = await _workerDocRef(uid);
    if (existingRef != null) {
      await existingRef.set(workerData, SetOptions(merge: true));
    } else {
      final workerName = (name ?? user?.displayName ?? '').trim();
      await _firestore
          .collection('workers')
          .doc(_workerDocId(workerName, uid))
          .set(workerData, SetOptions(merge: true));
    }

    // Mark profile as not yet complete in users collection
    final userRef1 = await _userDocRef(uid);
    if (userRef1 != null) await userRef1.update({'isProfileComplete': false});
  }

  /// Activate worker profile after completing registration
  Future<void> activateWorkerProfile({required String uid}) async {
    // Update workers collection
    final workerRef = await _workerDocRef(uid);
    if (workerRef != null) {
      await workerRef.update({'isSubscribed': true, 'status': 'active'});
    }

    // Update users collection
    final userRef2 = await _userDocRef(uid);
    if (userRef2 != null) await userRef2.update({'isProfileComplete': true});
  }

  /// Get worker profile data
  Future<Map<String, dynamic>?> getWorkerData(String uid) async {
    final workerRef = await _workerDocRef(uid);
    if (workerRef == null) return null;
    final doc = await workerRef.get();
    return doc.exists ? (doc.data() as Map<String, dynamic>?) : null;
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
