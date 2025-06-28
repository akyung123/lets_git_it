import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 사용자 ID(UID)를 가져오기 위함

// 올바른 각 화면 파일 임포트 (중복 임포트 문제 해결)
import 'package:my_app/volunteer/screens/calender_screen.dart';
import 'package:my_app/volunteer/screens/home_screen.dart';
import 'package:my_app/volunteer/screens/point_screen.dart';
import 'package:my_app/volunteer/screens/profile_screen.dart';


class MainScreen extends StatefulWidget {
  
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState(); // 괄호와 세미콜론 추가
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // 현재 선택된 탭의 인덱스 (0: 홈, 1: 캘린더, 2: 포인트, 3: 프로필)
  String? _currentUserId; // 현재 로그인된 사용자 ID (UID)를 저장할 변수

  // 각 탭에 해당하는 화면 목록
  // 각 화면에 사용자 ID를 전달하기 위해 위젯 생성 시 userId를 전달합니다.
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    // ----------------------------------------------------------------------
    // 핵심 수정 부분: Firebase 로그인 사용자가 없으면 'v2'를 사용합니다.
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_currentUserId == null) {
      // 로그인이 되어 있지 않다면, 'v2'를 임시 사용자 ID로 사용합니다.
      _currentUserId = 'v2';
      print("MainScreen: Firebase 로그인 사용자 없음. 테스트용 ID 'v2' 사용.");
    } else {
      print("MainScreen: 실제 로그인 사용자 UID = $_currentUserId");
    }
    // ----------------------------------------------------------------------

    // 사용자 ID를 각 화면에 전달하도록 초기화
    _widgetOptions = <Widget>[
      HomeScreen(userId: _currentUserId),
      CalendarScreen(userId: _currentUserId),
      PointScreen(userId: _currentUserId),
      ProfileScreen(userId: _currentUserId),
    ];
  }

  // 탭이 선택될 때 호출되는 함수
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    print("MainScreen: 선택된 탭 인덱스 = $index");
  }

  @override
  Widget build(BuildContext context) {
    // 이제 _currentUserId는 initState에서 항상 'v2' 또는 실제 UID로 설정되므로,
    // 이 null 체크는 일반적인 오류 메시지 대신 다른 용도로 사용하거나 제거할 수 있습니다.
    // 테스트 목적상 주석 처리하여 하단 탭 바가 바로 보이도록 합니다.
    // if (_currentUserId == null) {
    //   return Scaffold(
    //     appBar: AppBar(title: const Text('오류')),
    //     body: const Center(
    //       child: Text('사용자 ID를 가져올 수 없습니다. 앱을 재시작해주세요.'),
    //     ),
    //   );
    // }

    return Scaffold(
      body: IndexedStack( // IndexedStack을 사용하여 탭 전환 시 화면 상태를 유지합니다.
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: '일정'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star), // 또는 다른 포인트 관련 아이콘
            label: '포인트',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '프로필',
          ),
        ],
        currentIndex: _selectedIndex, // 현재 선택된 탭의 인덱스
        selectedItemColor: Colors.amber[800], // 선택된 아이템의 색상
        unselectedItemColor: Colors.grey, // 선택되지 않은 아이템의 색상
        onTap: _onItemTapped, // 탭 클릭 시 호출되는 함수
        type: BottomNavigationBarType.fixed, // 아이템이 4개 이상일 경우 고정
      ),
    );
  }
}