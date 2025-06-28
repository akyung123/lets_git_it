import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:my_app/volunteer/services/request.dart'; // Request 모델 임포트 경로 확인

class HomeScreen extends StatefulWidget {
  final String? userId; // LoginScreen에서 전달받는 사용자 ID

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Request 모델은 StreamBuilder 내에서 직접 사용하므로,
  // 여기서는 _requests 리스트를 제거하고 StreamBuilder의 스냅샷을 직접 활용합니다.
  // bool _isLoading = true; // StreamBuilder가 로딩 상태를 처리하므로 필요 없음

  @override
  void initState() {
    super.initState();
    // initState에서 _fetchRequests를 호출할 필요가 없습니다.
    // StreamBuilder가 실시간 데이터를 처리합니다.
  }

  // 이 함수는 더 이상 필요하지 않습니다. StreamBuilder가 데이터를 가져옵니다.
  /*
  Future<void> _fetchRequests() async {
    if (widget.userId == null) {
      print("HomeScreen: 사용자 ID가 null입니다. 요청을 가져올 수 없습니다.");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // 여기에서 'users' 컬렉션을 쿼리하는 것은 잘못되었습니다.
      // 'requests' 컬렉션에서 현재 사용자의 요청 내역을 가져와야 합니다.
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users') // <-- 이 부분이 잘못되었습니다. 'requests'로 변경해야 합니다.
          .where('requesterId', isEqualTo: id) // <-- 'id'가 정의되지 않았습니다. widget.userId를 사용해야 합니다.
          .limit(1)
          .get();

      setState(() {
        _requests = querySnapshot.docs.map((doc) => Request.fromFirestore(doc)).toList();
        _isLoading = false;
      });
      print("HomeScreen: ${_requests.length}개의 요청 정보 로드 완료.");
    } catch (e) {
      print("HomeScreen: 요청 정보 로드 중 오류 발생: $e");
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('요청 정보를 불러오는 데 실패했습니다: $e')),
        );
      }
    }
  }
  */

  void _onMoreOptionsPressed(Request request) {
    print("더보기 옵션 클릭됨: ${request.id}");
    // TODO: 요청 상세 정보 보기 또는 수정/취소 등의 옵션 팝업 표시
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '경북 경산시', // TODO: 실제 사용자 위치 또는 설정된 지역으로 동적 변경 필요
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            Icon(Icons.keyboard_arrow_down, color: Colors.black),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              /* TODO: 검색 기능 */
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {
              /* TODO: 알림 기능 */
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              /* TODO: 메뉴 기능 */
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>( // StreamBuilder를 사용하여 실시간 요청 내역을 가져옵니다.
        stream: FirebaseFirestore.instance
            .collection('requests') // 사용자 요청 내역은 'requests' 컬렉션에 있을 것입니다.
            .where('requesterId', isEqualTo: widget.userId) // 로그인한 사용자의 ID로 필터링
            .orderBy('createdAt', descending: true) // 최신 요청이 위로 오도록 정렬 (createdAt 필드가 있다고 가정)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator()); // 데이터 로딩 중
          }
          if (snapshot.hasError) {
            print("HomeScreen StreamBuilder 오류: ${snapshot.error}");
            return Center(
              child: Text('요청 내역을 불러오는 데 실패했습니다: ${snapshot.error}', textAlign: TextAlign.center),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('아직 등록된 요청이 없습니다.', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      // StreamBuilder는 자동으로 업데이트되므로, 강제 새로고침이 필요하면
                      // Future.delayed 등을 사용하여 잠시 로딩 표시 후 다시 빌드되도록 할 수 있습니다.
                      // 여기서는 단순히 메시지 표시용으로 남겨둡니다.
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('요청 내역을 새로고침합니다...')));
                    },
                    child: const Text('새로고침'),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data!.docs.map((doc) => Request.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '출발지: ${request.locationFrom}', // "출발지" 라벨 추가
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 지도 이미지 부분 (현재는 단순 아이콘)
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.blue[100],
                            ),
                            child: const Center(
                              child: Icon(Icons.map, color: Colors.blue, size: 30), // 아이콘 변경
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded( // 텍스트가 길어질 경우를 대비해 Expanded 추가
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '도착지: ${request.locationTo}', // "도착지" 라벨 추가
                                            style: const TextStyle(fontSize: 14, color: Colors.black), // 색상 변경
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '요청 시각: ${DateFormat('yyyy.MM.dd HH:mm').format(request.time)}', // 시간 형식 변경
                                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 더보기 아이콘
                                    IconButton(
                                      icon: const Icon(Icons.more_vert),
                                      onPressed: () => _onMoreOptionsPressed(request),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                // 포인트 정보 (화살표 포함)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${request.points ?? 0} pt', // points가 null일 경우 대비
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green), // 색상 추가
                                    ),
                                    // request.status에 따라 아이콘 변경 (선택 사항)
                                    _getStatusIcon(request.status),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // 상태 표시 추가
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          '상태: ${_getStatusText(request.status)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(request.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 요청 상태에 따른 아이콘 반환 함수 (추가)
  Widget _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return const Icon(Icons.hourglass_empty, color: Colors.orange, size: 24);
      case 'accepted':
        return const Icon(Icons.check_circle, color: Colors.green, size: 24);
      case 'completed':
        return const Icon(Icons.done_all, color: Colors.blue, size: 24);
      case 'cancelled':
        return const Icon(Icons.cancel, color: Colors.red, size: 24);
      default:
        return const Icon(Icons.info_outline, color: Colors.grey, size: 24);
    }
  }

  // 요청 상태에 따른 텍스트 반환 함수 (추가)
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return '매칭 대기 중';
      case 'accepted':
        return '매칭 완료';
      case 'completed':
        return '이동 완료';
      case 'cancelled':
        return '요청 취소됨';
      default:
        return '알 수 없는 상태';
    }
  }

  // 요청 상태에 따른 색상 반환 함수 (추가)
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return Colors.orange[600]!;
      case 'accepted':
        return Colors.green[600]!;
      case 'completed':
        return Colors.blue[600]!;
      case 'cancelled':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }
}

// Request 모델 (예시) - 실제 프로젝트 경로에 맞게 정의되어 있어야 합니다.
// services/request.dart 파일 내용이라고 가정합니다.
/*
class Request {
  final String id;
  final String requesterId;
  final String locationFrom;
  final String locationTo;
  final DateTime time; // Firestore Timestamp를 DateTime으로 변환했다고 가정
  final int points;
  final String status; // waiting, accepted, completed, cancelled 등

  Request({
    required this.id,
    required this.requesterId,
    required this.locationFrom,
    required this.locationTo,
    required this.time,
    required this.points,
    required this.status,
  });

  factory Request.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Request(
      id: doc.id,
      requesterId: data['requesterId'] ?? '',
      locationFrom: data['locationFrom'] ?? '알 수 없음',
      locationTo: data['locationTo'] ?? '알 수 없음',
      time: (data['time'] as Timestamp).toDate(), // Timestamp to DateTime
      points: (data['points'] ?? 0) as int,
      status: data['status'] ?? 'unknown',
    );
  }
}
*/