import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Service handling Firebase Cloud Messaging registration and message events.
///
/// Security Notice:
/// Mobile clients must NOT send push notifications directly using FCM server keys.
/// Notification delivery is triggered server-side via Cloud Functions when a new
/// message document is created in `conversations/{id}/messages/{messageId}`.
class NotificationService {
  NotificationService({
    required FirebaseMessaging messaging,
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _messaging = messaging,
       _firestore = firestore,
       _auth = auth;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  Future<void> initialize({
    void Function(String conversationId)? onNotificationTap,
  }) async {
    // 1. Request notification permissions
    final settings = await _messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _registerToken();
    }

    // 2. Listen to token refreshes
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      unawaited(_saveTokenToFirestore(token));
    });

    // 3. Handle foreground notifications
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (kDebugMode) {
        // Foreground message received
      }
    });

    // 4. Handle notification opened when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final conversationId = message.data['conversationId'] as String?;
      if (conversationId != null && onNotificationTap != null) {
        onNotificationTap(conversationId);
      }
    });

    // 5. Check if app was opened from a terminated state notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      final conversationId = initialMessage.data['conversationId'] as String?;
      if (conversationId != null && onNotificationTap != null) {
        onNotificationTap(conversationId);
      }
    }
  }

  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } on Object catch (_) {
      // Gracefully handle token registration errors
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token)
          .set({
            'token': token,
            'platform': defaultTargetPlatform.name,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } on Object catch (_) {
      // Ignore token save error if user is unauthenticated or offline
    }
  }

  Future<void> removeToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('fcmTokens')
            .doc(token)
            .delete();
      }
    } on Object catch (_) {
      // Ignore cleanup error
    }
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
  }
}
