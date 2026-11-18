import 'package:chat_app/core/error/exceptions.dart';
import 'package:chat_app/features/auth/domain/params/sign_in_request.dart';
import 'package:chat_app/features/auth/domain/params/sign_up_request.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';

abstract class FirebaseAuthDataSource {
  Future<Unit> signGoogle();
  Future<Unit> sendEmailVerification();
  Future<Unit> checkEmailVerified();
  Future<Unit> signIn(SignInRequest request);
  Future<Unit> signUp(SignUpRequest request);
  Future<Unit> logout();
  Future<Unit> deleteAccount();
  Future<bool> loggedIn();
  Future<Unit> resetPassword(String email);
  String? get currentUserId;
}

class FirebaseAuthDataSourceImpl implements FirebaseAuthDataSource {
  FirebaseAuthDataSourceImpl({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
    required GoogleSignIn googleSignIn,
    required this.logger,
  }) : _firebaseAuth = firebaseAuth,
       _firestore = firestore,
       _googleSignIn = googleSignIn;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  final Logger logger;
  bool _isGoogleSignInInitialized = false;

  @override
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_isGoogleSignInInitialized) return;
    try {
      await _googleSignIn.initialize(
        serverClientId:
            '639830188590-du60cqr6nmsqrtjqrl1nq76f8ue6na7n.apps.googleusercontent.com',
      );
      _isGoogleSignInInitialized = true;
    } on Exception catch (e) {
      logger.e('Failed to initialize GoogleSignIn: $e');
    }
  }

  @override
  Future<Unit> signUp(SignUpRequest request) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: request.email.trim(),
        password: request.password,
      );
      final user = userCredential.user;
      if (user == null) throw ServerException();

      await _firestore.collection('users').doc(user.uid).set({
        'name': request.name.trim(),
        'email': request.email.trim(),
        'photoUrl': null,
        'lastSeen': null,
        'isOnline': false,
        'createdAt': FieldValue.serverTimestamp(),
        'provider': 'email',
      });

      await user.sendEmailVerification();
      return unit;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw AlreadyRegisteredException();
        case 'weak-password':
          throw WeekPasswordException();
        case 'invalid-email':
          throw InvalidEmailException();
        case 'too-many-requests':
          throw TooManyRequestsException();
        default:
          logger.e(
            'FirebaseAuthException during signUp: ${e.code} - ${e.message}',
          );
          throw ServerException();
      }
    } on Exception catch (e) {
      if (e is AlreadyRegisteredException ||
          e is WeekPasswordException ||
          e is InvalidEmailException ||
          e is TooManyRequestsException ||
          e is ServerException) {
        rethrow;
      }
      logger.e('Unexpected exception during signUp: $e');
      throw UnExpectedException();
    }
  }

  @override
  Future<Unit> signIn(SignInRequest request) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: request.email.trim(),
        password: request.password,
      );
      final user = credential.user;
      if (user == null) throw ServerException();

      await user.reload();
      if (!user.emailVerified) {
        throw NotVerifiedException();
      }

      return unit;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw UserNotFoundException();
        case 'wrong-password':
          throw WrongPasswordException();
        case 'invalid-credential':
          throw SignInException();
        case 'invalid-email':
          throw InvalidEmailException();
        case 'user-disabled':
          throw UserDisabledException();
        case 'too-many-requests':
          throw TooManyRequestsException();
        default:
          logger.e(
            'FirebaseAuthException during signIn: ${e.code} - ${e.message}',
          );
          throw ServerException();
      }
    } on NotVerifiedException {
      rethrow;
    } on Exception catch (e) {
      if (e is UserNotFoundException ||
          e is WrongPasswordException ||
          e is SignInException ||
          e is InvalidEmailException ||
          e is UserDisabledException ||
          e is TooManyRequestsException ||
          e is ServerException) {
        rethrow;
      }
      logger.e('Unexpected exception during signIn: $e');
      throw UnExpectedException();
    }
  }

  @override
  Future<Unit> logout() async {
    try {
      await _firebaseAuth.signOut();
      try {
        await _googleSignIn.signOut();
      } on Exception catch (_) {
        // Ignore Google sign-out failures if not signed in with Google
      }
      return unit;
    } on Exception catch (e) {
      logger.e('Error during logout: $e');
      throw ServerException();
    }
  }

  @override
  Future<Unit> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw NotSignException();
    }

    final uid = user.uid;

    try {
      // 1. Delete authentication account first to avoid deleting Firestore data if auth deletion fails
      await user.delete();

      // 2. Clean up Firestore user profile
      await _firestore.collection('users').doc(uid).delete();

      // 3. Sign out local session
      await _firebaseAuth.signOut();
      return unit;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw RequiresRecentLoginException();
      }
      logger.e(
        'FirebaseAuthException during deleteAccount: ${e.code} - ${e.message}',
      );
      throw ServerException();
    } on Exception catch (e) {
      if (e is RequiresRecentLoginException) rethrow;
      logger.e('Unexpected error during deleteAccount: $e');
      throw ServerException();
    }
  }

  @override
  Future<Unit> signGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();

      final googleAccount = await _googleSignIn.authenticate();
      final googleAuth = googleAccount.authentication;

      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        logger.e('Google Sign-In returned null or empty idToken');
        throw ServerException();
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      final user = userCredential.user;
      if (user == null) throw ServerException();

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': user.displayName ?? (user.email?.split('@').first ?? 'User'),
          'email': user.email ?? '',
          'photoUrl': user.photoURL,
          'lastSeen': null,
          'isOnline': false,
          'createdAt': FieldValue.serverTimestamp(),
          'provider': 'google',
        });
      }

      return unit;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw GoogleSignInCancelledException();
      }
      logger.e('GoogleSignInException: ${e.code} - ${e.description}');
      throw ServerException();
    } on FirebaseAuthException catch (e) {
      logger.e(
        'FirebaseAuthException during signGoogle: ${e.code} - ${e.message}',
      );
      throw ServerException();
    } on Exception catch (e) {
      if (e is GoogleSignInCancelledException || e is ServerException) {
        rethrow;
      }
      logger.e('Unexpected exception during signGoogle: $e');
      throw UnExpectedException();
    }
  }

  @override
  Future<bool> loggedIn() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return false;
    }

    try {
      await user.reload();
      final refreshedUser = _firebaseAuth.currentUser;
      if (refreshedUser == null) {
        return false;
      }

      if (refreshedUser.emailVerified) {
        return true;
      } else {
        throw NotVerifiedException();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'user-disabled') {
        await _firebaseAuth.signOut();
        return false;
      }
      throw ServerException();
    } on NotVerifiedException {
      rethrow;
    } on Exception catch (_) {
      throw ServerException();
    }
  }

  @override
  Future<Unit> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw NotSignException();
    }

    try {
      await user.sendEmailVerification();
      return unit;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        throw TooManyRequestsException();
      }
      logger.e('FirebaseAuthException during sendEmailVerification: ${e.code}');
      throw ServerException();
    } on Exception catch (e) {
      if (e is TooManyRequestsException) rethrow;
      logger.e('Unexpected error during sendEmailVerification: $e');
      throw ServerException();
    }
  }

  @override
  Future<Unit> checkEmailVerified() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw NotSignException();
    }

    try {
      await user.reload();
      final refreshedUser = _firebaseAuth.currentUser;
      if (refreshedUser != null && refreshedUser.emailVerified) {
        return unit;
      } else {
        throw NotVerifiedException();
      }
    } on FirebaseAuthException catch (e) {
      logger.e('FirebaseAuthException during checkEmailVerified: ${e.code}');
      throw ServerException();
    }
  }

  @override
  Future<Unit> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      return unit;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw UserNotFoundException();
        case 'invalid-email':
          throw InvalidEmailException();
        case 'too-many-requests':
          throw TooManyRequestsException();
        default:
          logger.e(
            'FirebaseAuthException during resetPassword: ${e.code} - ${e.message}',
          );
          throw ServerException();
      }
    } on Exception catch (e) {
      if (e is UserNotFoundException ||
          e is InvalidEmailException ||
          e is TooManyRequestsException ||
          e is ServerException) {
        rethrow;
      }
      logger.e('Unexpected error during resetPassword: $e');
      throw UnExpectedException();
    }
  }
}
