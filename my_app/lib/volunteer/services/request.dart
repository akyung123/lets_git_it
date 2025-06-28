// lib/models/request.dart (수정된 버전)
import 'package:cloud_firestore/cloud_firestore.dart';

class Request {
  final String id;
  final DateTime createdAt;
  final String locationFrom;
  final String locationTo;
  final String? matchedVolunteerId;
  final String method;
  final String requesterId;
  final String status;
  final DateTime time;
  final int points; // points 필드는 이미지에 있으므로 유지

  Request({
    required this.id,
    required this.createdAt,
    required this.locationFrom,
    required this.locationTo,
    this.matchedVolunteerId,
    required this.method,
    required this.requesterId,
    required this.status,
    required this.time,
    this.points = 0, // points 필드 없으면 0으로 기본값 설정
  });

  factory Request.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;

    DateTime parsedCreatedAt;
    try {
      parsedCreatedAt = DateTime.parse(data['createdAt']);
    } catch (e) {
      print('Error parsing createdAt: ${data['createdAt']} -> $e');
      parsedCreatedAt = DateTime.now();
    }

    DateTime parsedTime;
    try {
      parsedTime = DateTime.parse(data['time']);
    } catch (e) {
      print('Error parsing time: ${data['time']} -> $e');
      parsedTime = DateTime.now();
    }

    return Request(
      id: doc.id,
      createdAt: parsedCreatedAt,
      locationFrom: data['locationFrom'] ?? '출발지 정보 없음',
      locationTo: data['locationTo'] ?? '도착지 정보 없음',
      matchedVolunteerId: data['matchedVolunteerId'],
      method: data['method'] ?? '방법 정보 없음',
      requesterId: data['requesterId'] ?? '요청자 정보 없음',
      status: data['status'] ?? '상태 정보 없음',
      time: parsedTime,
      points: data['points'] ?? 0, // 'points' 필드 없으면 0으로 가져옴
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'locationFrom': locationFrom,
      'locationTo': locationTo,
      'matchedVolunteerId': matchedVolunteerId,
      'method': method,
      'requesterId': requesterId,
      'status': status,
      'time': time.toIso8601String(),
      'points': points,
    };
  }
}