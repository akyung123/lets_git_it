import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/eider/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController idController = TextEditingController();
  bool isLoading = false;

  Future<void> loginUser() async {
    String id = idController.text.trim();

    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인식번호(id)를 입력하세요')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('id', isEqualTo: id)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data() as Map<String, dynamic>;
        final userId = querySnapshot.docs.first.id;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${userData['name']}님 환영합니다!')),
        );

        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(id: userId)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('해당 인식 번호가 존재하지 않습니다.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 중 오류 발생: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '로그인',
          style: TextStyle(fontWeight: FontWeight.bold), // AppBar 제목 굵게
        ),
        centerTitle: true, // 제목 중앙 정렬
      ),
      body: GestureDetector(
        onTap: () {
          // 화면의 다른 곳을 탭하면 키보드 숨기기
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView( // 키보드가 올라올 때 화면이 가려지지 않도록 스크롤 추가
          child: Padding(
            padding: const EdgeInsets.all(30.0), // 전체적인 여백 증가
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // 세로축 중앙 정렬
              crossAxisAlignment: CrossAxisAlignment.stretch, // 가로축 꽉 채우기
              children: [
                // 앱 로고나 제목 등을 추가할 수 있는 공간
                const Center(
                  child: Text(
                    '환영합니다',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 50),
                TextField(
                  controller: idController,
                  style: const TextStyle(fontSize: 18.0), // 입력 텍스트 크기 증가
                  decoration: const InputDecoration(
                    labelText: '인식번호 입력',
                    labelStyle: TextStyle(fontSize: 18.0), // 라벨 텍스트 크기 증가
                    contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0), // 내부 여백
                    border: OutlineInputBorder( // 테두리 스타일
                      borderRadius: BorderRadius.all(Radius.circular(10.0)),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: isLoading ? null : loginUser,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15), // 버튼 내부 상하 여백
                    shape: RoundedRectangleBorder( // 버튼 모서리 둥글게
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle( // 버튼 텍스트 스타일
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox( // 로딩 인디케이터 크기 조절
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3.0,
                          ),
                        )
                      : const Text('로그인'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

