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
    if (widget.userId == null) {
      print("ProfileScreen: 사용자 ID가 null입니다. 프로필 정보를 가져올 수 없습니다.");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data() ?? {};
          _isLoading = false;
        });
        print("ProfileScreen: 사용자 ${widget.userId}의 프로필 정보 로드 완료.");
      } else {
        print("ProfileScreen: 사용자 문서가 Firestore에 존재하지 않습니다: ${widget.userId}");
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("ProfileScreen: 프로필 정보 로드 중 오류 발생: $e");
      setState(() {
        _isLoading = false;
      });
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
      await FirebaseAuth.instance.signOut();
      print("ProfileScreen: 로그아웃 성공!");
      // 로그아웃 후 로그인 화면으로 이동 (main.dart의 StreamBuilder가 자동으로 처리)
      // 또는 명시적으로 pushAndRemoveUntil을 사용할 수도 있습니다.
      // 예: Navigator.of(context).pushAndRemoveUntil(
      //       MaterialPageRoute(builder: (context) => const PhoneLoginScreen()),
      //       (Route<dynamic> route) => false,
      //     );
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
      appBar: AppBar(
        title: const Text('프로필 화면'),
        actions: [
          // 로그아웃 버튼을 여기에 추가합니다.
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: '로그아웃',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUserProfile, // 새로고침 버튼
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '현재 사용자 ID: ${widget.userId ?? "알 수 없음"}',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileRow('이름', _userData['name'] ?? '설정되지 않음'),
                          _buildProfileRow('전화번호', _userData['phone'] ?? '설정되지 않음'),
                          _buildProfileRow('역할', (_userData['role'] ?? false) ? '자원봉사자' : '일반 사용자'),
                          _buildProfileRow('관리자 여부', (_userData['isAdmin'] ?? false) ? '예' : '아니오'),
                          _buildProfileRow('인증된 봉사자 여부', (_userData['isVerifiedVolunteer'] ?? false) ? '예' : '아니오'),
                          // 필요한 다른 프로필 정보들을 추가하세요.
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: 프로필 편집 화면으로 이동하는 로직 추가
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('프로필 편집 기능 (구현 예정)')),
                        );
                      },
                      child: const Text('프로필 편집'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}