// lib/models/request.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Request {
  final String? id;
  final DateTime createdAt;
  final String locationFrom;
  final String locationTo;
  final String? matchedVolunteerId;
  final String method;
  final String requesterId;
  final String status;
  final DateTime time;
  //final int? points;  // point 추가되면 업데이트


  Request({
    this.id,
    required this.createdAt,
    required this.locationFrom,
    required this.locationTo,
    this.matchedVolunteerId,
    required this.method,
    required this.requesterId,
    required this.status,
    required this.time,
  });

  factory Request.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;

    // 🌟🌟🌟 이 부분이 수정되어야 합니다! 🌟🌟🌟
    // Firestore에서 가져온 Timestamp를 Dart의 DateTime으로 변환합니다.

    // createdAt 필드 처리
    DateTime parsedCreatedAt;
    if (data['createdAt'] is Timestamp) {
      parsedCreatedAt = (data['createdAt'] as Timestamp).toDate();
    } else {
      // Timestamp가 아닌 다른 타입 (예: String)으로 저장되어 있을 경우를 대비한 방어로직.
      // 하지만 오류 메시지로 보아 이 경우는 아닐 가능성이 높습니다.
      try {
        parsedCreatedAt = DateTime.parse(data['createdAt'].toString());
      } catch (e) {
        print("Warning: Could not parse createdAt from Firestore: ${data['createdAt']}, Error: $e");
        parsedCreatedAt = DateTime.now(); // 파싱 실패 시 기본값 (현재 시간) 설정
      }
    }

    // time 필드 처리
    DateTime parsedTime;
    if (data['time'] is Timestamp) {
      parsedTime = (data['time'] as Timestamp).toDate();
    } else {
      // Timestamp가 아닌 다른 타입 (예: String)으로 저장되어 있을 경우를 대비한 방어로직.
      try {
        parsedTime = DateTime.parse(data['time'].toString());
      } catch (e) {
        print("Warning: Could not parse time from Firestore: ${data['time']}, Error: $e");
        parsedTime = DateTime.now(); // 파싱 실패 시 기본값 (현재 시간) 설정
      }
    }


    return Request(
      id: doc.id,
      createdAt: parsedCreatedAt, // 변환된 DateTime 사용
      locationFrom: data['locationFrom'],
      locationTo: data['locationTo'],
      matchedVolunteerId: data['matchedVolunteerId'],
      method: data['method'],
      requesterId: data['requesterId'],
      status: data['status'],
      time: parsedTime, // 변환된 DateTime 사용
    );
  }

  Map<String, dynamic> toFirestore() {
    // 🌟🌟🌟 toFirestore는 현재 잘 되어 있습니다 (String으로 저장).
    // 하지만 Firestore에 저장할 때 DateTime 객체를 Timestamp로 변환하여 저장하는 것이
    // Firestore의 날짜 타입 이점을 활용하고, 읽어올 때 Timestamp로 일관되게 처리하는 데 더 좋습니다.
    // 만약 String으로 저장하는 것을 유지하고 싶다면 이 부분은 그대로 두세요.
    // 저의 권장사항은 다음과 같습니다:
    return {
      'createdAt': Timestamp.fromDate(createdAt), // DateTime -> Timestamp 변환
      'locationFrom': locationFrom,
      'locationTo': locationTo,
      'matchedVolunteerId': matchedVolunteerId,
      'method': method,
      'requesterId': requesterId,
      'status': status,
      'time': Timestamp.fromDate(time),           // DateTime -> Timestamp 변환
    };

    // 만약 계속 String으로 저장하고 싶다면 아래 코드 유지:
    /*
    return {
      'createdAt': createdAt.toIso8601String(),
      'locationFrom': locationFrom,
      'locationTo': locationTo,
      'matchedVolunteerId': matchedVolunteerId,
      'method': method,
      'requesterId': requesterId,
      'status': status,
      'time': time.toIso8601String(),
    };
    */
  }
}