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
    recordedPath = '${dir.path}/recorded_audio.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        bitRate: 128000,
        numChannels: 1,
      ),
      path: recordedPath!,
    );
    isRecording = true;
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    isRecording = false;
    recordedPath = path;
    return path;
  }

  Future<File?> getRecordedFile() async {
    if (recordedPath == null) return null;
    return File(recordedPath!);
  }
}
