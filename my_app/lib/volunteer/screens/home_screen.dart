// lib/volunteer/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/volunteer/services/request.dart';

class HomeScreen extends StatefulWidget {
  final String? userId;
  const HomeScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('requests')
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('경북 경산시'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.menu)),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final err = snapshot.error;
            final msg = (err is FirebaseException && err.code=='failed-precondition')
                ? 'Firestore 인덱스를 생성해주세요.'
                : '오류 발생: \$err';
            return Center(child: Text(msg, textAlign: TextAlign.center));
          }
          final docs = snapshot.data?.docs;
          if (docs == null || docs.isEmpty) {
            return const Center(child: Text('대기 중인 요청이 없습니다.'));
          }
          final requests = docs.map((d) => Request.fromFirestore(d)).toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) => RequestCard(
              request: requests[index],
              userId: widget.userId,
            ),
          );
        },
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  final Request request;
  final String? userId;
  const RequestCard({Key? key, required this.request, this.userId}) : super(key: key);

  Future<void> _join(BuildContext ctx) async {
    if (userId == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('사용자 정보가 없습니다.'), backgroundColor: Colors.red),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(request.id)
          .update({'status': 'matched', 'matchedVolunteerId': userId});
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('참여되었습니다!'), backgroundColor: Colors.blue),
      );
    } catch (e) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('오류 발생: \$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 올바른 문자열 보간 사용
    final dist = (1 + (request.id!.hashCode % 5)).toStringAsFixed(1);
    final pts = (10 + (request.id!.hashCode % 30)).toString();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RequestDetailScreen(request: request, userId: userId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.map, size: 40, color: Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$dist km',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('$pts pt',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700])),
                        const Icon(Icons.arrow_forward_ios, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF67B5ED), // 버튼 색 변경
                  ),
                  onPressed: () => _join(context),
                  child: const Text('참여'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RequestDetailScreen extends StatelessWidget {
  final Request request;
  final String? userId;
  const RequestDetailScreen({Key? key, required this.request, this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final date = request.createdAt.toLocal().toString().split(' ')[0];
    final hour = request.time.toLocal().hour.toString().padLeft(2, '0');
    final minute = request.time.toLocal().minute.toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text('요청 상세 정보')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('요청일'),
            subtitle: Text(date),
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('시간'),
            subtitle: Text('$hour:$minute'),
          ),
          ListTile(
            leading: const Icon(Icons.directions_car),
            title: const Text('방법'),
            subtitle: Text(request.method),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('출발지'),
            subtitle: Text(request.locationFrom),
          ),
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('도착지'),
            subtitle: Text(request.locationTo),
          ),
        ],
      ),
    );
  }
}

