import 'package:flutter/material.dart';
import 'smsverification_generalaccount.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TourAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Plus Jakarta Sans',
        primaryColor: const Color(0xFF13a4ec),
        scaffoldBackgroundColor: const Color(0xFFF6F7F8),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF111618)),
        ),
      ),
      home: const SMSVerificationGeneralAccount(),
    );
  }
}