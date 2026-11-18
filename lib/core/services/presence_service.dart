import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Manages user presence and online status based on application lifecycle.
///
/// NOTE on Architecture:
/// For production-grade presence that handles sudden disconnections (such as
/// force close, battery death, or network loss), Firebase Realtime Database's
/// `.info/connected` with `.onDisconnect()` mirrored to Cloud Firestore via
/// Cloud Functions is recommended.
///
/// This service provides client lifecycle-level synchronization with Firestore.
class PresenceService {
  PresenceService({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _auth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  AppLifecycleListener? _lifecycleListener;

  void initialize() {
    _lifecycleListener = AppLifecycleListener(
      onResume: () => setPresence(isOnline: true),
      onPause: () => setPresence(isOnline: false),
      onDetach: () => setPresence(isOnline: false),
      onHide: () => setPresence(isOnline: false),
    );

    // Initial presence if user is already signed in
    if (_auth.currentUser != null) {
      unawaited(setPresence(isOnline: true));
    }
  }

  Future<void> setPresence({required bool isOnline}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } on Object catch (_) {
      // Presence updates should fail gracefully without disrupting user experience
    }
  }

  Future<void> handleSignOut() async {
    await setPresence(isOnline: false);
  }

  void dispose() {
    _lifecycleListener?.dispose();
  }
}
