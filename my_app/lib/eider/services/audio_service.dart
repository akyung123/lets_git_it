import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  bool isRecording = false;
  String? recordedPath;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    final dir = await getApplicationDocumentsDirectory();

    // 고유한 파일명 생성 (덮어쓰기 방지, 디버깅에 도움)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    recordedPath = '${dir.path}/recorded_audio_$timestamp.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        bitRate: 128000,
        numChannels: 1,
      ),
      path: recordedPath!, // 지정된 경로로 녹음
    );
    isRecording = true;
  }

  Future<String?> stopRecording() async {
    await _recorder.stop(); // 반환된 path는 사용하지 않음
    isRecording = false;

    if (recordedPath != null && await File(recordedPath!).exists()) {
      return recordedPath;
    } else {
      return null; // 존재하지 않는다면 오류 처리
    }
  }

  Future<File?> getRecordedFile() async {
    if (recordedPath == null) return null;
    final file = File(recordedPath!);
    return await file.exists() ? file : null;
  }
}
