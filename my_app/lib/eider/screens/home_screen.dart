import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/eider/services/upload_voice_service.dart';
import '../services/audio_service.dart';

class HomeScreen extends StatefulWidget {
  final String id; // 이용자 id
  const HomeScreen({Key? key, required this.id}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioService _audioService = AudioService();
  bool _isUploading = false; // 음성 업로드 중임을 나타내는 상태 변수 추가

  Future<void> handleVoiceButton() async {
    // 녹음 시작 로직
    if (!_audioService.isRecording) {
      final granted = await _audioService.hasPermission();
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('녹음 권한이 필요합니다.'), behavior: SnackBarBehavior.floating),
        );
        return;
      }

      print('[DEBUG] 녹음 시작 시도');
      await _audioService.startRecording();
      print('[DEBUG] 녹음 시작 완료');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎤 녹음을 시작합니다.'), behavior: SnackBarBehavior.floating),
      );
    }
    // 녹음 중지 및 업로드 로직
    else {
      print('[DEBUG] 녹음 중지 시도');
      setState(() {
        _isUploading = true; // 업로드 시작
      });

      final path = await _audioService.stopRecording();
      if (path == null) {
        print('[ERROR] 녹음 중지 실패: path가 null');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('녹음 중지 실패! 다시 시도해주세요.'), behavior: SnackBarBehavior.floating),
        );
        setState(() {
          _isUploading = false; // 업로드 실패 시 상태 초기화
        });
        return;
      }

      final file = await _audioService.getRecordedFile();
      if (file == null || !(await file.exists())) {
        print('[ERROR] 파일이 존재하지 않음');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('녹음 파일이 생성되지 않았습니다.'), behavior: SnackBarBehavior.floating),
        );
        setState(() {
          _isUploading = false; // 업로드 실패 시 상태 초기화
        });
        return;
      }

      print('[DEBUG] 파일 경로: $path (${await file.length()} bytes)');
      print('[DEBUG] 녹음 파일 존재 여부: ${await File(path).exists()}');
      print('[DEBUG] 녹음 파일 크기: ${await File(path).length()} bytes');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ 녹음 완료! 요청을 처리 중입니다.'), behavior: SnackBarBehavior.floating),
      );

      // 음성 업로드
      try {
        await uploadWavToFastAPI(path, widget.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('요청이 성공적으로 전송되었습니다!'), behavior: SnackBarBehavior.floating),
        );
      } catch (e) {
        print('[ERROR] 음성 업로드 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('요청 전송 실패: $e'), behavior: SnackBarBehavior.floating),
        );
      } finally {
        setState(() {
          _isUploading = false; // 업로드 완료 또는 실패 시 상태 초기화
        });
      }
    }
    // _audioService.isRecording 상태가 변경되었으므로 UI 업데이트
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '이동 요청',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24, // AppBar 제목 글자 크기 증가
            color: Colors.white, // 제목 색상 변경
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo[900], // AppBar 배경색 변경
        elevation: 0, // AppBar 그림자 제거
      ),
      body: Column(
        children: [
          // '이동 요청하기' 버튼 섹션
          Container(
            width: double.infinity, // 가로 전체 차지
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 25.0), // 상하좌우 여백
            color: Colors.indigo[800], // 섹션 배경색
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '음성으로 편리하게 이동을 요청하세요!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.7, // 화면 너비의 70% 차지
                  height: 100, // 버튼 높이 증가
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : handleVoiceButton, // 업로드 중이면 버튼 비활성화
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, // 텍스트/아이콘 색상
                      backgroundColor: _audioService.isRecording ? Colors.redAccent : Colors.green, // 녹음 중이면 빨강, 아니면 초록
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50), // 둥근 버튼 모양
                      ),
                      elevation: 8, // 버튼 그림자
                    ),
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white) // 업로드 중 로딩 인디케이터
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _audioService.isRecording ? Icons.stop : Icons.mic,
                                size: 40, // 아이콘 크기 증가
                              ),
                              const SizedBox(width: 15),
                              Text(
                                _audioService.isRecording ? '녹음 중지' : '이동 요청하기',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold), // 글자 크기 및 굵기 증가
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _audioService.isRecording ? '말씀을 마친 후 다시 눌러주세요.' : '버튼을 눌러 음성으로 요청을 시작하세요.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white60,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 15), // 섹션 간 간격

          // 요청 내역 제목
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '나의 요청 내역',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),

          // 요청 내역 리스트 섹션
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .where('requesterId', isEqualTo: widget.id)
                  .orderBy('timestamp', descending: true) // 최신 요청이 위로 오도록 정렬 (timestamp 필드가 있다고 가정)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print('[ERROR] 요청 내역 스트림 오류: ${snapshot.error}');
                  return Center(
                      child: Text(
                    '데이터를 불러오는 중 오류가 발생했습니다: ${snapshot.error}',
                    style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text(
                    '아직 요청 내역이 없습니다.\n"이동 요청하기" 버튼을 눌러보세요!',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ));
                }

                final requests = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index].data() as Map<String, dynamic>;
                    // Firestore 문서에 'timestamp' 필드가 없으면 현재 시간 사용 (예시)
                    final timestamp = (request['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final formattedTime = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
                    final requestDate = '${timestamp.month}/${timestamp.day}';
                    final status = request['status'] ?? '상태 없음'; // 'status' 필드가 없을 경우 대비

                    // 상태에 따라 색상과 아이콘 변경
                    Color statusColor;
                    IconData statusIcon;
                    String statusText;

                    switch (status.toLowerCase()) {
                      case 'pending':
                        statusColor = Colors.orange[600]!;
                        statusIcon = Icons.hourglass_empty;
                        statusText = '매칭 대기 중';
                        break;
                      case 'accepted':
                        statusColor = Colors.green[600]!;
                        statusIcon = Icons.check_circle;
                        statusText = '기사님 매칭 완료';
                        break;
                      case 'completed':
                        statusColor = Colors.blue[600]!;
                        statusIcon = Icons.done_all;
                        statusText = '이동 완료';
                        break;
                      case 'cancelled':
                        statusColor = Colors.red[600]!;
                        statusIcon = Icons.cancel;
                        statusText = '요청 취소됨';
                        break;
                      default:
                        statusColor = Colors.grey[600]!;
                        statusIcon = Icons.info_outline;
                        statusText = '알 수 없는 상태';
                        break;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 5.0),
                      elevation: 4, // 카드 그림자
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Row(
                          children: [
                            Icon(statusIcon, size: 35, color: statusColor),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$statusText',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '요청 시각: $requestDate $formattedTime',
                                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                                  ),
                                  // 'destination' 필드가 있다면 추가 표시
                                  if (request.containsKey('destination') && request['destination'] != null)
                                    Text(
                                      '목적지: ${request['destination']}',
                                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                                    ),
                                  // 'driverName' 필드가 있다면 추가 표시
                                  if (request.containsKey('driverName') && request['driverName'] != null)
                                    Text(
                                      '기사님: ${request['driverName']}',
                                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                                    ),
                                ],
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
          ),
        ],
      ),
    );
  }
}