import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final String? userId; // MainScreen으로부터 전달받을 사용자 ID

  const HomeScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('홈 화면'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '환영합니다, 홈 화면입니다!',
              style: TextStyle(fontSize: 24),
            ),
            if (userId != null)
              Text(
                '현재 사용자 ID: $userId', // 전달받은 사용자 ID 표시
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            // TODO: 홈 화면의 실제 콘텐츠를 여기에 추가하세요.
          ],
        ),
      ),
    );
  }
}