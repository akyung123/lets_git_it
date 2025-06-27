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

  bool isLoading = false; // 로딩 상태 수

  Future<void> loginUser() async {
    String id = idController.text.trim();
    
    if (id.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인식번호(id)를 입력하세요')),
      );
      return ;
    }

    setState(() {
      isLoading = true; // 로딩 시작
    });

    // login 관련 DB 확인 후, 인식번호로 로그인
    try {
      final QuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('id', isEqualTo: id)
          .limit(1)
          .get();
        
      if (QuerySnapshot.docs.isNotEmpty) {
          final userData = QuerySnapshot.docs.first.data();
          final userId = QuerySnapshot.docs.first.id;

          // 로그인 성공 처리
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${userData['name']}님 환영합니다!')),
          );

          // Home_screen으로 이동시켜야함
          Navigator.push(context, MaterialPageRoute(builder: (_) => HomeScreen(id: userId))); 
        } else {
          // id가 없음
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('해당 인식 번호가 존재하지않습)니다.')),
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
    build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(title: const Text('로그인')),
        body : Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: '인식번호 입력',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: isLoading ? null : loginUser,
              child: isLoading ? const CircularProgressIndicator()
              : const Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}