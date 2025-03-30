import 'package:flutter/material.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    // 请求所有必要的权限
    await [
      Permission.storage,
      Permission.notification,
    ].request();

    // Android 10及以上需要特殊处理
    if (await Permission.storage.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }

  runApp(const MyApp());
}
