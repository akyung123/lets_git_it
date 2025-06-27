import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final baseUrl = dotenv.env['API_BASE_URL'];

Future<void> uploadWavToFastAPI(String filePath, String userId) async {
  final uri = Uri.parse('$baseUrl/request/voice?user_id=$userId');

  final request = http.MultipartRequest('POST', uri);
  // 파일은 audio_file 이라는 이름으로 추가
  request.files.add(
    await http.MultipartFile.fromPath(
      'audio_file', // ← FastAPI 쪽에서 지정한 필드명과 일치해야 함
      filePath,
      filename: basename(filePath),
      contentType: MediaType('audio', 'wav'),
    ),
  );

  try {
    final response = await request.send();
    final res = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      print('✅ 서버 응답: $res');
    } else {
      print('❌ 업로드 실패: ${response.statusCode}, 응답 내용: $res');
    }
  } catch (e) {
    print('❌ 요청 중 예외 발생: $e');
  }
}
