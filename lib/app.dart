import 'package:flutter/material.dart';
import 'screens/home_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '习惯打卡',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5E7CE2), // 主题蓝色
          brightness: Brightness.light,
          secondary: const Color(0xFF4CAF50), // 绿色作为次要颜色
        ),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        fontFamily: 'PingFang SC', // 使用苹方字体
      ),
      home: const MyHomePage(),
    );
  }
}
