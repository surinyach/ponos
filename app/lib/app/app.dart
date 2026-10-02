import 'package:flutter/material.dart';

import '../features/home/presentation/home_page.dart';
import 'theme/app_theme.dart';

class PonosApp extends StatelessWidget {
  const PonosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ponos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: const HomePage(),
    );
  }
}
