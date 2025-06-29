import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  final String _baseUrl = "https://elderly-care-backend-8216020119.us-central1.run.app";

  Future<Map<String, dynamic>> _sendVoiceRequest({
    required String endpoint,
    required String userId,
    required String audioFilePath,
    String? pendingRequestId,
  }) async {
    final Map<String, String> queryParams = {'user_id': userId};
    if (pendingRequestId != null) {
      queryParams['pending_request_id'] = pendingRequestId;
    }
    final uri = Uri.parse("$_baseUrl$endpoint").replace(queryParameters: queryParams);
    print("✅ [ApiService] Sending request to: $uri");

    try {
      final request = http.MultipartRequest('POST', uri);
      final audioFile = await http.MultipartFile.fromPath(
        'audio_file',
        audioFilePath,
        filename: path.basename(audioFilePath),
        contentType: MediaType('audio', 'wav'),
      );
      request.files.add(audioFile);

      print("✅ [ApiService] Sending Multipart request...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // --- 중요 로그 추가 ---
      print("✅ [ApiService] Response Status Code: ${response.statusCode}");
      final responseBody = utf8.decode(response.bodyBytes);
      print("✅ [ApiService] Response Body: $responseBody");
      // --- 중요 로그 끝 ---

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody);
      } else {
        print("❌ [ApiService] Server returned an error.");
        throw Exception('서버로부터 에러 응답을 받았습니다: ${response.statusCode}');
      }
    } on SocketException {
      print("❌ [ApiService] Network connection error.");
      throw Exception('네트워크 연결을 확인해주세요.');
    } catch (e) {
      print("❌ [ApiService] An unexpected error occurred: $e");
      throw Exception('알 수 없는 오류가 발생했습니다: $e');
    }
  }

  Future<Map<String, dynamic>> sendInitialVoiceRequest({
    required String userId,
    required String audioFilePath,
  }) {
    print("✅ [ApiService] Preparing initial voice request.");
    return _sendVoiceRequest(
      endpoint: '/request/voice',
      userId: userId,
      audioFilePath: audioFilePath,
    );
  }

  Future<Map<String, dynamic>> sendContinuationVoiceRequest({
    required String userId,
    required String audioFilePath,
    required String pendingRequestId,
  }) {
    print("✅ [ApiService] Preparing continuation voice request.");
    return _sendVoiceRequest(
      endpoint: '/request/voice/continue',
      userId: userId,
      audioFilePath: audioFilePath,
      pendingRequestId: pendingRequestId,
    );
  }
}