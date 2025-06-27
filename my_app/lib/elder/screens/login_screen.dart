import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        const SnackBar(content: Text('인식번호(id)를 입력하세요요')),
      );
      return ;
    }

    setState(() {
      isLoading = true; // 로딩 시작
    });

    // login 관련 DB 확인 후, 인식번호로 로그인
    try {
      final QuerySnapshot = await FirebaseFirestore.instance
          .collection('user')
          .where('id', isEqualTo: id)
          .limit(1)
          .get();
        
      if (QuerySnapshot.docs.isNotEmpty) {
          final userData = QuerySnapshot.docs.first.data();
          
        }
    }


}