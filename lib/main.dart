import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:pads/app/service/audio_player_service.dart';

import 'app/routes/app_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Get.putAsync(() async => AudioPlayerService()); 
  runApp(
    GetMaterialApp(
      title: "Audio Pads",
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
    ),
  );
}
