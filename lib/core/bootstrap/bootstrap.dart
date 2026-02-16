import 'package:chat_app/firebase_options.dart';
import 'package:chat_app/injection_container.dart' as di;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';

class Bootstrap {
  static Future<void> init() async {
    await ScreenUtil.ensureScreenSize();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await GetStorage.init();
    await di.init();
  }
}
