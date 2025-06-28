// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/volunteer/services/request.dart';

class HomeScreen extends StatefulWidget {
  final String? userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold( // HomeScreen 자체에 Scaffold를 두어 AppBar를 가질 수 있도록 합니다.
      appBar: AppBar(
        title: const Text('경북 경산시'), // 상단 제목
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // 검색 기능 구현
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // 알림 기능 구현
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              // 메뉴 기능 구현
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('requests').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('에러 발생: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('요청이 없습니다.'));
          }

          final requests = snapshot.data!.docs.map((doc) => Request.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return RequestCard(request: request);
            },
          );
        },
      ),
      // HomeScreen에서는 BottomNavigationBar를 제거합니다. MainScreen에서 관리합니다.
    );
  }
}

// 개별 요청 카드를 위한 위젯 (변경 없음)
class RequestCard extends StatelessWidget {
  final Request request;

  const RequestCard({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽 지도 및 핀 아이콘 (임시)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Icon(Icons.map, size: 50, color: Colors.blue),
            ),
            const SizedBox(width: 16.0),
            // 가운데 요청 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '경북 경산시',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text('${(1 + (request.id!.hashCode % 5)).toStringAsFixed(1)}km',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Text('요청일: ${request.createdAt.toLocal().toString().split(' ')[0]}'),
                  Text('시간: ${request.time.toLocal().hour}시 ${request.time.toLocal().minute}분'),
                  Text('방법: ${request.method}'),
                  Text('출발: ${request.locationFrom}'),
                  Text('도착: ${request.locationTo}'),
                  Text('상태: ${request.status}'),
                  Text('${(10 + (request.id!.hashCode % 30))} pt',
                    style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            // 오른쪽 화살표 및 더보기 아이콘
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    // 더보기 메뉴 기능 구현
                  },
                ),
                const SizedBox(height: 10),
                const Icon(Icons.arrow_forward),
              ],
            ),
          ],
        ),
      ),
    );
  }
}