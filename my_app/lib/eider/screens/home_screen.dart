import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/eider/services/upload_voice_service.dart';
import '../services/audio_service.dart';

class HomeScreen extends StatefulWidget{
  final String id;  // 이용자 id
  const HomeScreen({Key? key, required this.id})
      : super(key:key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioService _audioService = AudioService();

 Future<void> handleVoiceButton() async {
  if (!_audioService.isRecording) {
    final granted = await _audioService.hasPermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹음 권한이 필요합니다.')),
      );
      return;
    }

    print('[DEBUG] 녹음 시작 시도');
    await _audioService.startRecording();
    print('[DEBUG] 녹음 시작 완료');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('녹음 시작')),
    );
  } else {
    print('[DEBUG] 녹음 중지 시도');
    final path = await _audioService.stopRecording();
    if (path == null) {
      print('[ERROR] 녹음 중지 실패: path가 null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹음 중지 실패')),
      );
      return;
    }

    final file = await _audioService.getRecordedFile();
    if (file == null || !(await file.exists())) {
      print('[ERROR] 파일이 존재하지 않음');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹음 파일이 생성되지 않았습니다.')),
      );
      return;
    }

    print('[DEBUG] 파일 경로: $path (${await file.length()} bytes)');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('녹음 완료 : $path')),
    );

    await uploadWavToFastAPI(path);  // 전송은 마지막에
  }

  setState(() {});
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이동 요청'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(onPressed: handleVoiceButton, child: Text(_audioService.isRecording ? '녹음 중지' : '이동 요청하기'),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                .collection('requests')
                .where('requesterId', isEqualTo: widget.id)
                .snapshots(), 
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('요청 내역이 없습니다.'));
                }
                final requests = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return ListTile(
                      title: Text('상태: ${request['status']}'),
                      subtitle: const Text('매칭 중인 상태'),
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