import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show VoidCallback, kIsWeb;
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  ConfirmationResult? _webConfirmationResult;

  FirebaseAuthPlatform get _authPlatformDelegate {
    return FirebaseAuthPlatform.instanceFor(
      app: Firebase.app(),
      pluginConstants: <dynamic, dynamic>{},
    );
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String message) onVerificationFailed,
    VoidCallback? onAutoVerified,
  }) async {
    final normalizedPhone = phoneNumber.trim();
    if (normalizedPhone.isEmpty) {
      onVerificationFailed('Enter a valid phone number.');
      return;
    }

    if (kIsWeb) {
      try {
        _webConfirmationResult = await _auth.signInWithPhoneNumber(
          normalizedPhone,
          RecaptchaVerifier(
            auth: _authPlatformDelegate,
            onSuccess: () {},
            onError: (error) {
              onVerificationFailed(
                error.message ?? 'reCAPTCHA failed. Please try again.',
              );
            },
            onExpired: () {
              onVerificationFailed('reCAPTCHA expired. Please request a new OTP.');
            },
          ),
        );
        onCodeSent('web_confirmation', null);
      } catch (e) {
        onVerificationFailed('Could not send OTP on web: $e');
      }
      return;
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: normalizedPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        final result = await _auth.signInWithCredential(credential);
        await ensureStarterUser(
          user: result.user,
          phoneNumber: normalizedPhone,
        );
        onAutoVerified?.call();
      },
      verificationFailed: (exception) {
        onVerificationFailed(
          exception.message ?? 'Could not send OTP. Please try again.',
        );
      },
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (verificationId) {
        onCodeSent(verificationId, null);
      },
    );
  }

  Future<User?> verifyOtp({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  }) async {
    if (kIsWeb) {
      final confirmationResult = _webConfirmationResult;
      if (confirmationResult == null) {
        throw Exception('OTP session expired. Please request a new code.');
      }
      final result = await confirmationResult.confirm(smsCode.trim());
      await ensureStarterUser(user: result.user, phoneNumber: phoneNumber);
      return result.user;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    final result = await _auth.signInWithCredential(credential);
    await ensureStarterUser(user: result.user, phoneNumber: phoneNumber);
    return result.user;
  }

  Future<void> ensureStarterUser({
    required User? user,
    required String phoneNumber,
  }) async {
    if (user == null) {
      return;
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await userRef.get();
    final existing = snapshot.data() ?? <String, dynamic>{};

    await userRef.set({
      'uid': user.uid,
      'phoneNumber': phoneNumber,
      'isProfileComplete': existing['isProfileComplete'] ?? false,
      'name': existing['name'] ?? '',
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

  Future<void> saveUser({
    required String uid,
    required String name,
    required String email,
    required String role,
    String? photoUrl,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'photoUrl': photoUrl ?? '',
      'isProfileComplete': role == 'customer',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

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

    if (latitude != null && longitude != null) {
      final geoFirePoint = GeoFirePoint(GeoPoint(latitude, longitude));
      workerData['position'] = geoFirePoint.data;
      workerData['latitude'] = latitude;
      workerData['longitude'] = longitude;
    }

    await _firestore
        .collection('workers')
        .doc(uid)
        .set(workerData, SetOptions(merge: true));

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'isProfileComplete': false,
    }, SetOptions(merge: true));
  }

  Future<void> activateWorkerProfile({required String uid}) async {
    await _firestore.collection('workers').doc(uid).set({
      'uid': uid,
      'isSubscribed': true,
      'status': 'active',
    }, SetOptions(merge: true));

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'isProfileComplete': true,
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getWorkerData(String uid) async {
    final byId = await _firestore.collection('workers').doc(uid).get();
    if (byId.exists) {
      return byId.data();
    }

    final fallback = await _firestore
        .collection('workers')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (fallback.docs.isNotEmpty) {
      return fallback.docs.first.data();
    }
    return null;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
