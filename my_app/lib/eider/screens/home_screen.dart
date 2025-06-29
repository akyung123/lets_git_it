import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/eider/request_viewmodel.dart';
import 'package:my_app/eider/services/audio_service.dart';

class HomeScreen extends StatefulWidget {
  final String id; // 이용자 id
  const HomeScreen({Key? key, required this.id}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioService _audioService = AudioService();
  late final RequestViewModel _requestViewModel;

  int _continuationCount = 0;
  final int _maxAttempts = 10; // 최대 재시도 횟수

  @override
  void initState() {
    super.initState();
    _requestViewModel = RequestViewModel();
    _requestViewModel.addListener(_onViewModelStateChanged);
  }

  @override
  void dispose() {
    _requestViewModel.removeListener(_onViewModelStateChanged);
    _requestViewModel.dispose();
    super.dispose();
  }

  void _onViewModelStateChanged() {
    if (!mounted) return;
    final state = _requestViewModel.state;
    final messenger = ScaffoldMessenger.of(context);

    if (state == RequestState.success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ 요청이 성공적으로 접수되었습니다!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _resetRequestProcess();

    } else if (state == RequestState.error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ 오류 발생: ${_requestViewModel.errorMessage}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _resetRequestProcess();

    } else if (state == RequestState.incomplete) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('🔄 추가 녹음이 필요합니다. 남은 횟수: ${_maxAttempts - _continuationCount}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _resetRequestProcess() {
    _continuationCount = 0;
    _requestViewModel.reset();
    if (_audioService.isRecording) {
      _audioService.stopRecording();
    }
    setState(() {});
  }

  Future<void> _toggleRecording() async {
    if (!_audioService.isRecording) {
      final granted = await _audioService.hasPermission();
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('녹음 권한이 필요합니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await _audioService.startRecording();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎤 녹음을 시작합니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final path = await _audioService.stopRecording();
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('녹음 파일 저장에 실패했습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await _processVoiceRequest(path);
    }
    setState(() {});
  }

  Future<void> _processVoiceRequest(String audioFilePath) async {
    final currentState = _requestViewModel.state;
    if (currentState == RequestState.incomplete) {
      _continuationCount++;
      if (_continuationCount >= _maxAttempts) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('최대 재시도 횟수를 초과했습니다. 처음부터 다시 시도해주세요.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _resetRequestProcess();
        return;
      }
      // 후속 요청 (서버 API 호출 via ApiService inside ViewModel)
      await _requestViewModel.processContinuationRequest(widget.id, audioFilePath);
    } else {
      _continuationCount = 1;
      // 최초 요청 (서버 API 호출 via ApiService inside ViewModel)
      await _requestViewModel.processInitialRequest(widget.id, audioFilePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vmState = _requestViewModel.state;
    final isRecording = _audioService.isRecording;
    final isLoading = vmState == RequestState.loading;
    final isIncomplete = vmState == RequestState.incomplete;

    String buttonText;
    if (isRecording) {
      buttonText = '녹음 중지';
    } else if (isIncomplete) {
      buttonText = '답변 녹음하기';
    } else {
      buttonText = '이동 요청하기';
    }

    String instructionText;
    if (isLoading) {
      instructionText = '요청을 처리 중입니다. 잠시만 기다려주세요...';
    } else if (isRecording) {
      instructionText = '말씀을 마친 후 다시 눌러주세요.';
    } else if (isIncomplete) {
      instructionText = _requestViewModel.clarificationPrompt ??
          '추가 정보가 필요합니다. 답변을 녹음해주세요.';
    } else {
      instructionText = '버튼을 눌러 음성 요청을 시작하세요.';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '이동 요청',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo[900],
        elevation: 0,
      ),
      body: Column(
        children: [
          // 녹음 & 요청 섹션
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
            color: Colors.indigo[800],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isIncomplete ? '추가 질문' : '음성으로 이동 요청하기',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isIncomplete ? Colors.yellowAccent : Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: 100,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _toggleRecording,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: isRecording ? Colors.redAccent : Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      elevation: 8,
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isRecording ? Icons.stop : Icons.mic, size: 40),
                              const SizedBox(width: 15),
                              Text(buttonText, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  instructionText,
                  style: TextStyle(fontSize: 16, color: isIncomplete ? Colors.white : Colors.white60),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          // 요청 내역 리스트
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('나의 요청 내역', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .where('requesterId', isEqualTo: widget.id)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('데이터를 불러오는 중 오류가 발생했습니다:\n${snapshot.error}', style: const TextStyle(fontSize: 16, color: Colors.redAccent), textAlign: TextAlign.center),
                  );
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('아직 요청 내역이 없습니다.\n"이동 요청하기" 버튼을 눌러보세요!', style: TextStyle(fontSize: 18, color: Colors.grey), textAlign: TextAlign.center));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final ts = (data['createdAt'] as Timestamp).toDate();
                    final formattedTime = '${ts.month}/${ts.day} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
                    final status = (data['status'] ?? '').toString().toLowerCase();
                    Color statusColor;
                    IconData statusIcon;
                    String statusText;
                    switch (status) {
                      case 'matched':
                        statusColor = Colors.green[600]!;
                        statusIcon = Icons.check_circle;
                        statusText = '기사님 매칭 완료';
                        break;
                      case 'done':
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
                        statusColor = Colors.orange[600]!;
                        statusIcon = Icons.hourglass_empty;
                        statusText = '매칭 대기 중';
                    }
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          children: [
                            Icon(statusIcon, size: 35, color: statusColor),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(statusText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor)),
                                  const SizedBox(height: 5),
                                  if (data['destination'] != null)
                                  if (data['driverName'] != null)
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
