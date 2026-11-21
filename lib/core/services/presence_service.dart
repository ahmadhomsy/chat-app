import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';

/// Manages real-time user presence with multi-device support.
///
/// Architecture:
/// - Realtime Database (RTDB) connection records are the SOLE source of truth
///   for active device connections.
/// - Connects to Firebase Realtime Database `.info/connected`.
/// - Registers a unique device connection key under `/status/{uid}/connections/{deviceId}`.
/// - Configures `.onDisconnect().remove()` on the device connection key.
/// - Configures `.onDisconnect().set(ServerValue.timestamp)` on `/status/{uid}/lastSeen`.
/// - Server-side Cloud Function (`onUserStatusChanged`) authoritatively aggregates active
///   connections and mirrors `isOnline` and `lastSeen` to Cloud Firestore.
/// - Mobile clients NEVER write directly to Firestore `isOnline` or `lastSeen` fields,
///   which are strictly protected by Firestore Security Rules.
/// - Multi-device safe: closing, backgrounding, or detaching one device never marks the
///   user offline if another active device connection remains in RTDB.
/// - Disconnection and reconnection are idempotent.
class PresenceService {
  PresenceService({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
    FirebaseDatabase? database,
    String? deviceId,
    this.onPresenceChanged,
  }) : _firestore = firestore,
       _auth = firebaseAuth,
       _database = database,
       _deviceId = deviceId ?? DateTime.now().microsecondsSinceEpoch.toString();

  // ignore: unused_field, Retained for dependency injection compatibility.
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseDatabase? _database;
  final String _deviceId;

  /// Optional callback for unit tests and local UI notification.
  final Future<void> Function({required String uid, required bool isOnline})?
  onPresenceChanged;

  AppLifecycleListener? _lifecycleListener;
  StreamSubscription<DatabaseEvent>? _connectedSubscription;
  StreamSubscription<DatabaseEvent>? _connectionsSubscription;
  DatabaseReference? _myConnectionRef;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Setup app lifecycle listener for mobile state transitions
    _lifecycleListener = AppLifecycleListener(
      onResume: _handleResume,
      onPause: _handlePause,
      onDetach: _handleDetach,
      onHide: _handlePause,
    );

    // 2. Setup Realtime Database presence
    _setupRtdbPresence();
  }

  void _setupRtdbPresence() {
    if (_database == null) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Listen to Realtime Database connection status
    final connectedRef = _database.ref('.info/connected');
    _connectedSubscription = connectedRef.onValue.listen((event) async {
      final isConnected = event.snapshot.value == true;
      if (!isConnected) return;

      final currentUid = _auth.currentUser?.uid;
      if (currentUid == null) return;

      // Reference for this specific device connection
      final myConn = _database.ref('status/$currentUid/connections/$_deviceId');
      _myConnectionRef = myConn;

      // On disconnect, automatically remove this device connection from RTDB
      await myConn.onDisconnect().remove();

      // On disconnect, update lastSeen in RTDB
      await _database
          .ref('status/$currentUid/lastSeen')
          .onDisconnect()
          .set(ServerValue.timestamp);

      // Mark this device connected in RTDB
      await myConn.set(true);

      // Listen to total active connections for this user across all devices
      await _listenToUserConnections(currentUid);
    });
  }

  Future<void> _listenToUserConnections(String uid) async {
    if (_database == null) return;
    await _connectionsSubscription?.cancel();

    final connectionsRef = _database.ref('status/$uid/connections');
    _connectionsSubscription = connectionsRef.onValue.listen((event) {
      final hasActiveDevices =
          event.snapshot.exists && event.snapshot.children.isNotEmpty;

      // Inform optional listener (used for local UI/testing)
      if (onPresenceChanged != null) {
        unawaited(onPresenceChanged!(uid: uid, isOnline: hasActiveDevices));
      }
    });
  }

  void _handleResume() {
    if (_myConnectionRef != null) {
      unawaited(_myConnectionRef!.set(true));
    }
  }

  void _handlePause() {
    // When paused or backgrounded, remove this device connection from RTDB.
    // User remains online in Firestore if another device is active.
    if (_myConnectionRef != null) {
      unawaited(_myConnectionRef!.remove());
    }
  }

  void _handleDetach() {
    // When detached, remove this device connection from RTDB.
    // Does NOT directly write offline to Firestore; server handles presence aggregation.
    if (_myConnectionRef != null) {
      unawaited(_myConnectionRef!.remove());
    }
  }

  /// Sets presence locally or notifies test listeners.
  /// Direct client writes to Firestore presence fields are prohibited by Security Rules
  /// and handled solely by Cloud Functions on RTDB state transitions.
  Future<void> setFirestorePresence({required bool isOnline}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    if (onPresenceChanged != null) {
      await onPresenceChanged!(uid: uid, isOnline: isOnline);
    }
  }

  Future<void> handleSignOut() async {
    // 1. Remove this device connection from RTDB
    if (_myConnectionRef != null) {
      try {
        await _myConnectionRef!.remove();
      } on Object catch (_) {}
      _myConnectionRef = null;
    }

    // 2. Notify optional listener
    final uid = _auth.currentUser?.uid;
    if (uid != null && onPresenceChanged != null) {
      await onPresenceChanged!(uid: uid, isOnline: false);
    }

    // 3. Cancel subscriptions
    await _connectedSubscription?.cancel();
    await _connectionsSubscription?.cancel();
    _connectedSubscription = null;
    _connectionsSubscription = null;
  }

  void dispose() {
    _lifecycleListener?.dispose();
    unawaited(_connectedSubscription?.cancel());
    unawaited(_connectionsSubscription?.cancel());
  }
}
