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

      await _audioService.startRecording();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹음 시작')),
      );
    } else {
      final path = await _audioService.stopRecording();
      await uploadWavToFastAPI(path!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('녹음 완료 : $path')),
      );
      final file = await _audioService.getRecordedFile();
      print('녹음 파일: $path (${await file?.length()} bytes)');

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