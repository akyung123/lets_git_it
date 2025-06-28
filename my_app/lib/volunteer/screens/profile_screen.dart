import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore에서 사용자 데이터를 가져오기 위함
import 'package:firebase_auth/firebase_auth.dart'; // 로그아웃 기능에 사용

class ProfileScreen extends StatefulWidget {
  final String? userId; // MainScreen으로부터 전달받을 사용자 ID

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _userData = {}; // 사용자 프로필 데이터를 저장할 변수
  bool _isLoading = true; // 데이터 로딩 상태

  @override
  void initState() {
    super.initState();
    _fetchUserProfile(); // 화면 초기화 시 사용자 프로필 정보 가져오기
  }

  Future<void> _fetchUserProfile() async {
    // userId가 null이면 프로필 정보를 가져올 수 없음
    if (widget.userId == null) {
      print("ProfileScreen: 사용자 ID가 null입니다. 프로필 정보를 가져올 수 없습니다.");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // 'users' 컬렉션에서 해당 userId의 문서 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        // 문서가 존재하면 데이터 설정
        setState(() {
          _userData = userDoc.data() ?? {};
          _isLoading = false;
        });
        print("ProfileScreen: 사용자 ${widget.userId}의 프로필 정보 로드 완료.");
      } else {
        // 사용자 문서가 존재하지 않을 경우
        print("ProfileScreen: 사용자 문서가 Firestore에 존재하지 않습니다: ${widget.userId}");
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // 데이터 로드 중 오류 발생 시 처리
      print("ProfileScreen: 프로필 정보 로드 중 오류 발생: $e");
      setState(() {
        _isLoading = false;
      });
      // 위젯이 마운트된 상태인지 확인 후 SnackBar 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 정보를 불러오는 데 실패했습니다: $e')),
        );
      }
    }
  }

  // 로그아웃 함수
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut(); // Firebase에서 로그아웃
      print("ProfileScreen: 로그아웃 성공!");
      // 로그아웃 후 로그인 화면으로 이동 (대부분 main.dart의 StreamBuilder가 처리)
      // 또는 명시적으로 라우팅을 통해 로그인 화면으로 이동할 수 있습니다.
      // 예: Navigator.of(context).pushAndRemoveUntil(
      //          MaterialPageRoute(builder: (context) => const PhoneLoginScreen()),
      //          (Route<dynamic> route) => false,
      //      );
    } catch (e) {
      print("ProfileScreen: 로그아웃 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("로그아웃 실패: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], // 배경색을 회색으로 변경 (이미지와 유사하게)
      appBar: AppBar(
        backgroundColor: Colors.grey[200], // 앱바 배경색도 회색으로 설정
        elevation: 0, // 앱바 그림자 제거
        title: const Text(
          '내 정보',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false, // 제목 왼쪽 정렬
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black), // 설정 아이콘
            onPressed: () {
              // TODO: 설정 화면으로 이동 로직
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('설정 기능 (구현 예정)')),
              );
            },
          ),
        ],
      ),
      body: _isLoading // 데이터 로딩 중이면 로딩 인디케이터 표시
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView( // 내용이 많아질 경우 스크롤 가능하도록
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 사용자 정보 카드 섹션 ---
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 프로필 아이콘 (원형)
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[300], // 아이콘 배경색
                            child: const Icon(Icons.person, size: 40, color: Colors.black54), // 사람 아이콘
                          ),
                          const SizedBox(width: 15),
                          // 사용자 이름, 나이, 주소
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userData['name'] ?? '이름 미설정', // '이름' 필드
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  // 'age' 필드가 있다면 사용, 없으면 '정보 없음'
                                  _userData['age'] != null ? '${_userData['age']}세' : '나이 정보 없음',
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                Text(
                                  // 'address' 필드가 있다면 사용, 없으면 '정보 없음'
                                  _userData['address'] ?? '주소 정보 없음',
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 18), // 화살표 아이콘
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16), // 카드 사이 간격

                  // --- 두 번째 빈 카드 섹션 ---
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: const SizedBox(
                      height: 120, // 임시 높이
                      width: double.infinity, // 가로로 꽉 채우기
                      child: Center(
                        // 이 부분에 원하는 내용 추가 (예: 포인트, 알림 등)
                        child: Text('여기에 다른 정보나 기능 추가'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16), // 카드 사이 간격

                  // --- 세 번째 빈 카드 섹션 (더 길게) ---
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: const SizedBox(
                      height: 200, // 임시 높이
                      width: double.infinity, // 가로로 꽉 채우기
                      child: Center(
                        // 이 부분에 원하는 내용 추가 (예: 내가 쓴 글, 활동 내역 등)
                        child: Text('여기에 더 많은 정보나 기능 추가'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- 로그아웃 및 새로고침 버튼 (카드 형태로) ---
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.refresh, color: Colors.blue),
                          title: const Text('프로필 새로고침'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                          onTap: _fetchUserProfile, // 새로고침 기능 연결
                        ),
                        const Divider(height: 0, indent: 16, endIndent: 16), // 구분선
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text('로그아웃'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                          onTap: _logout, // 로그아웃 기능 연결
                        ),
                      ],
                    ),
                  ),
                  // TODO: 프로필 편집 버튼은 이와 유사한 방식으로 다른 카드 섹션에 배치하거나, 프로필 정보 카드 onTap에 연결할 수 있습니다.
                ],
              ),
            ),
    );
  }
}