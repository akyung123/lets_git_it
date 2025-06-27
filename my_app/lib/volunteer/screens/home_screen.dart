import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required String id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: DropdownButton<String>(
          value: '경북 경산시',
          underline: SizedBox(),
          icon: Icon(Icons.arrow_drop_down, color: Colors.white),
          items: ['경북 경산시', '대구 달서구'].map((location) {
            return DropdownMenuItem<String>(
              value: location,
              child: Text(location),
            );
          }).toList(),
          onChanged: (value) {},
        ),
        actions: [
          IconButton(icon: Icon(Icons.notifications_none), onPressed: () {}),
          IconButton(icon: Icon(Icons.menu), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildRequestCard(
            imageAsset: 'assets/map1.png',
            name: '김해 김민서',
            date: '2025.05.13',
            points: 40,
            distance: '3.5km',
          ),
          _buildRequestCard(
            imageAsset: 'assets/map2.png',
            name: '경북 경산시',
            date: '2025.05.30',
            points: 25,
            distance: '2.0km',
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '일정'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: '기록'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '채팅'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
        ],
      ),
    );
  }

  Widget _buildRequestCard({
    required String imageAsset,
    required String name,
    required String date,
    required int points,
    required String distance,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Image.asset(imageAsset, width: 60, height: 60, fit: BoxFit.cover),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name),
            Text(distance, style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date),
            Text('$points pt'),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () {
          // 상세 요청 페이지 이동
        },
      ),
    );
  }
}
