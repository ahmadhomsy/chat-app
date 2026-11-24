import 'package:bloc/bloc.dart';
import 'package:chat_app/app.dart';
import 'package:chat_app/core/bootstrap/bootstrap.dart';
import 'package:chat_app/core/helpers/bloc_obs.dart';
import 'package:chat_app/firebase_options_staging.dart';
import 'package:chat_app/injection_container.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Bootstrap.init(
    firebaseOptions: DefaultFirebaseOptionsStaging.currentPlatform,
  );
  Bloc.observer = sl<MyBlocObserver>();
  runApp(const MyApp());
}
