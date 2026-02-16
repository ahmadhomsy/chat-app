import 'package:bloc/bloc.dart';
import 'package:chat_app/app.dart';
import 'package:chat_app/core/bootstrap/bootstrap.dart';
import 'package:chat_app/core/helpers/bloc_obs.dart';
import 'package:chat_app/injection_container.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = sl<MyBlocObserver>();
  await Bootstrap.init();
  runApp(const MyApp());
}
