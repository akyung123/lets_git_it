import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// FirebaseAuth는 직접 사용되지 않지만, 다른 연관 로직에 필요할 수 있으므로 유지.

class PointScreen extends StatefulWidget {
  final String? userId; // MainScreen으로부터 전달받을 사용자 ID

  const PointScreen({super.key, required this.userId});

  @override
  State<PointScreen> createState() => _PointScreenState();
}

class _PointScreenState extends State<PointScreen> {
  int _userPoint = 0; // 사용자 포인트를 저장할 변수
  List<dynamic> _pointLogs = []; // 포인트 로그를 저장할 변수
  bool _isLoading = true; // 데이터 로딩 상태
  String? _selectedFilter = '전체'; // 필터 드롭다운의 현재 선택 값

  @override
  void initState() {
    super.initState();
    _fetchUserPoints(); // 화면 초기화 시 사용자 포인트 정보 가져오기
  }

  Future<void> _fetchUserPoints() async {
    if (widget.userId == null) {
      print("PointScreen: 사용자 ID가 null입니다. 포인트 정보를 가져올 수 없습니다.");
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
        final data = userDoc.data();
        setState(() {
          _userPoint = data?['point'] ?? 0;
          _pointLogs = data?['pointLogs'] ?? [];
          _isLoading = false;
        });
        print("PointScreen: 사용자 ${widget.userId}의 포인트 정보 로드 완료. 포인트: $_userPoint");
      } else {
        print("PointScreen: 사용자 문서가 Firestore에 존재하지 않습니다: ${widget.userId}");
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("PointScreen: 포인트 정보 로드 중 오류 발생: $e");
      setState(() {
        _isLoading = false;
      });
      // 화면이 마운트된 상태일 때만 SnackBar를 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('포인트 정보를 불러오는 데 실패했습니다: $e')),
        );
      }
    }
  }

  // TODO: 실제 필터링 로직 구현 (현재는 UI만)
  void _onFilterChanged(String? newValue) {
    setState(() {
      _selectedFilter = newValue;
      // 여기에 필터링된 _pointLogs를 다시 로드하거나, 기존 _pointLogs에서 필터링하는 로직 추가
    });
  }

  // TODO: '포인트 사용' 클릭 시 호출될 함수
  void _onPointUsePressed() {
    print("포인트 사용 버튼 클릭!");
    // Navigator를 사용하여 포인트 사용 화면으로 이동하는 로직 추가
    // Navigator.push(context, MaterialPageRoute(builder: (context) => PointUseScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // 배경색을 사진과 유사하게 설정
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView( // 스크롤 가능하도록 CustomScrollView 사용
              slivers: [
                SliverAppBar(
                  expandedHeight: 230.0, // AppBar의 확장된 높이
                  floating: true, // 스크롤 시 AppBar가 나타나게 함
                  pinned: true, // 스크롤 시 AppBar가 상단에 고정되게 함
                  backgroundColor: const Color(0xFF67B5ED), // 사진의 하늘색 계열
                  elevation: 0, // 그림자 제거
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context); // 뒤로가기 버튼
                    },
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: Colors.white),
                      onPressed: () { /* TODO: 알림 기능 */ },
                    ),
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () { /* TODO: 메뉴 기능 */ },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                      // 상단 포인트 카드 부분
                    background: Padding(
                      padding: const EdgeInsets.only(top: kToolbarHeight + 10, left: 16, right: 16, bottom: 0),
                      child: Align(
                        alignment: Alignment.center,
                        child: Card(
                          elevation: 0, // 그림자 제거
                          color: const Color(0xFF4C98E3), // 사진의 어두운 파란색 계열
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: SizedBox(
                            width: double.infinity,
                            height: 120, // 카드의 높이 조절
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$_userPoint pt',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32, // 폰트 크기 조절
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell( // '포인트 사용 →' 텍스트에 클릭 이벤트 추가
                                  onTap: _onPointUsePressed, // TODO: 포인트 사용 함수 연결
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                    child: Text(
                                      '포인트 사용 →',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '포인트 적립 내역',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedFilter,
                                  icon: const Icon(Icons.arrow_drop_down),
                                  style: const TextStyle(color: Colors.black, fontSize: 16),
                                  onChanged: _onFilterChanged, // TODO: 필터 변경 함수 연결
                                  items: <String>['전체', '적립', '사용'] // 필터 옵션
                                      .map<DropdownMenuItem<String>>((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () { /* TODO: 검색 기능 */ },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (_pointLogs.isEmpty) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text('포인트 내역이 없습니다.'),
                        ));
                      }
                      final log = _pointLogs[index];
                      // 사진과 유사한 ListTile 디자인
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Card(
                          elevation: 0.5, // 카드 그림자 조절
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            title: Text(
                              (log['type'] == '적립' ? '+' : '-') + '${log['amount'] ?? 0} pt',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: log['type'] == '적립' ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                            subtitle: Text(
                              log['description'] ?? '내용 없음',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            onTap: () {
                              // TODO: 내역 상세 보기 기능
                              print('내역 클릭: ${log['description']}');
                            },
                          ),
                        ),
                      );
                    },
                    childCount: _pointLogs.isEmpty ? 1 : _pointLogs.length, // 내역이 없으면 '내역이 없습니다' 텍스트만 표시
                  ),
                ),
              ],
            ),
    );
  }
}