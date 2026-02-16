import 'package:flutter_bloc/flutter_bloc.dart';

class TabsCubit extends Cubit<int> {
  TabsCubit() : super(0); // 0 = All Friends

  void changeTab(int index) {
    emit(index);
  }
}
