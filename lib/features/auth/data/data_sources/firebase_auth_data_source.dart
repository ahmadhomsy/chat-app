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
  @override
  Future<Unit> signUp(SignUpRequest request) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: request.email,
        password: request.password,
      );
      final user = userCredential.user;
      if (user == null) throw ServerException();
      await _firestore.collection('users').doc(user.uid).set({
        'name': request.name,
        'email': request.email,
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
        default:
          logger.e(e);
          throw ServerException();
      }
    } on Exception catch (_) {
      throw UnExpectedException();
    }
  }

  @override
  Future<Unit> signIn(SignInRequest request) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: request.email,
        password: request.password,
      );
      return unit;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
          throw SignInException();
        case 'invalid-email':
          throw InvalidEmailException();
        default:
          logger.e(e.code);
          throw ServerException();
      }
    } on Exception catch (_) {
      throw UnExpectedException();
    }
  }

  @override
  Future<Unit> logout() async {
    try {
      await _firebaseAuth.signOut();
      return unit;
    } on Exception catch (_) {
      throw ServerException();
    }
  }

  @override
  Future<Unit> deleteAccount() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      final user = FirebaseAuth.instance.currentUser;
      await user?.delete();
      await _firebaseAuth.signOut();
      return unit;
    } on Exception catch (_) {
      throw ServerException();
    }
  }

  @override
  Future<Unit> signGoogle() async {
    try {
      // final GoogleSignIn _googleSignIn = GoogleSignIn(
      //   serverClientId:
      //       '639830188590-du60cqr6nmsqrtjqrl1nq76f8ue6na7n.apps.googleusercontent.com',
      //   scopes: ['email'],
      // );
      // final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      //
      // final GoogleSignInAuthentication? googleAuth =
      //     await googleUser?.authentication;
      //
      // final credential = GoogleAuthProvider.credential(
      //   accessToken: googleAuth?.accessToken,
      //   idToken: googleAuth?.idToken,
      // );
      // // Once signed in, return the UserCredential
      // // return await FirebaseAuth.instance.signInWithCredential(credential);
      //***************************************************************
      // _googleSignIn.initialize(
      //   serverClientId:
      //       "639830188590-du60cqr6nmsqrtjqrl1nq76f8ue6na7n.apps.googleusercontent.com",
      // );
      // final GoogleSignInAccount? googleUser = await _googleSignIn
      //     .authenticate();
      //
      // // Obtain the auth details from the request
      // final GoogleSignInAuthentication? googleAuth =
      //     await googleUser?.authentication;
      //
      // // Create a new credential
      // final credential = GoogleAuthProvider.credential(
      //   accessToken: googleAuth?.idToken,
      //   idToken: googleAuth?.idToken,
      // );
      //**********************************************************************
      await _googleSignIn.initialize(
        serverClientId:
            '639830188590-du60cqr6nmsqrtjqrl1nq76f8ue6na7n.apps.googleusercontent.com',
      );
      final googleAccount = await _googleSignIn.authenticate();

      final googleAuth = googleAccount.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      final user = userCredential.user;
      if (user == null) throw ServerException();

      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': user.displayName ?? 'user',
          'email': user.email ?? '',
          'photoUrl': null,
          'lastSeen': null,
          'isOnline': false,
          'createdAt': FieldValue.serverTimestamp(),
          'provider': 'google',
        });
      }

      return unit;
    } on FirebaseAuthException {
      throw ServerException();
    } on Exception catch (e) {
      logger.e(e);

      throw UnExpectedException();
    }
  }

  @override
  Future<bool> loggedIn() async {
    if (_firebaseAuth.currentUser != null) {
      await _firebaseAuth.currentUser!.reload();
      _firebaseAuth.currentUser!.emailVerified;
      if (_firebaseAuth.currentUser!.emailVerified) {
        return true;
      } else {
        throw NotVerifiedException();
      }
    } else {
      return false;
    }
  }

  @override
  Future<Unit> sendEmailVerification() async {
    try {
      await _firebaseAuth.currentUser!.sendEmailVerification();
      return unit;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        throw TooManyRequestsException();
      } else {
        throw ServerException();
      }
    } on Exception catch (_) {
      throw ServerException();
    }
  }

  @override
  Future<Unit> checkEmailVerified() async {
    await _firebaseAuth.currentUser!.reload();
    _firebaseAuth.currentUser!.emailVerified;
    if (_firebaseAuth.currentUser!.emailVerified) {
      return unit;
    } else {
      throw NotVerifiedException();
    }
  }
}
