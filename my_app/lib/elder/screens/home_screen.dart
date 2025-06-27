import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// 당일 할 일 화면 끌어오기 혹은 만들기

class HomeScreen extends StatelessWidget{
  final String id;  // 이용자 id

  const HomeScreen({Key? key, required this.id})
      : super(key:key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이동 요청'),
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('id')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(cjild test() )
          }
        }),
    )
    throw UnimplementedError();
  }
}
 ''