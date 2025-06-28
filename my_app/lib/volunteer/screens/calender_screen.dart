// lib/screens/calendar_screen.dart
import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  final String? userId;
  const CalendarScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('캘린더 화면')),
      body: Center(child: Text('캘린더 내용. 사용자 ID: $userId')),
    );
  }
}

