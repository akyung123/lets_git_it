import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final baseUrl = dotenv.env['API_BASE_URL'];

Future<void> uploadWavToFastAPI(String filePath) async {
  final uri = Uri.parse('$baseUrl/request/voice');

  final request = http.MultipartRequest('POST', uri);
  request.files.add(
    await http.MultipartFile.fromPath(
      'file',
      filePath,
      filename: basename(filePath),
      contentType: MediaType('audio', 'wav'),
    ),
  );

  final response = await request.send();
  final res = await response.stream.bytesToString();

  if (response.statusCode == 200) {
    print('✅ 서버 응답: $res');
  } else {
    print('❌ 업로드 실패: ${response.statusCode}');
  }
}
