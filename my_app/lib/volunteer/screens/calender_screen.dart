// lib/volunteer/screens/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:my_app/volunteer/services/request.dart';
import 'package:my_app/volunteer/screens/home_screen.dart';

class CalendarScreen extends StatefulWidget {
  final String? userId;
  const CalendarScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedDay;

  final Map<DateTime, List<Request>> _events = {};
  List<Request> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    // 로케일 데이터 초기화 (Intl)
    initializeDateFormatting('ko_KR', null).then((_) {
      setState(() {});
    });
    _selectedDay = _focusedDay;
    _selectedEvents = [];
  }

  DateTime _normalizeDate(DateTime date) => DateTime.utc(date.year, date.month, date.day);

  List<Request> _getEventsForDay(DateTime day) {
    return _events[_normalizeDate(day)] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _selectedEvents = _getEventsForDay(selectedDay);
    });
  }

  @override
  Widget build(BuildContext context) {
    final requestsStream = FirebaseFirestore.instance
        .collection('requests')
        .where('matchedVolunteerId', isEqualTo: widget.userId)
        .where('status', whereIn: ['accepted', 'done'])
        .orderBy('matchedVolunteerId')
        .orderBy('status')
        .orderBy('time')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 일정'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: requestsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final err = snapshot.error;
            final msg = (err is FirebaseException && err.code == 'failed-precondition')
                ? 'Firestore 인덱스를 생성해주세요.'
                : '오류 발생: \$err';
            return Center(child: Text(msg, textAlign: TextAlign.center));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('참여한 일정이 없습니다.', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HomeScreen(userId: widget.userId),
                          ),
                        ),
                        child: const Text('요청 보러 가기'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final requests = docs.map((doc) => Request.fromFirestore(doc)).toList();
          _events.clear();
          for (var req in requests) {
            final day = _normalizeDate(req.time);
            _events.putIfAbsent(day, () => []).add(req);
          }
          _selectedEvents = _getEventsForDay(_selectedDay);

          return Column(
            children: [
              TableCalendar<Request>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                calendarFormat: _calendarFormat,
                eventLoader: _getEventsForDay,
                onDaySelected: _onDaySelected,
                onFormatChanged: (format) => setState(() => _calendarFormat = format),
                onPageChanged: (focused) => _focusedDay = focused,
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextFormatter: (date, locale) => DateFormat('yyyy.MM').format(date),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                locale: 'ko_KR',
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _selectedEvents.isEmpty
                    ? const Center(child: Text('선택된 날짜에 일정이 없습니다.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: _selectedEvents.length,
                        itemBuilder: (context, index) {
                          final e = _selectedEvents[index];
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.event),
                              title: Text('${e.locationFrom} → ${e.locationTo}'),
                              subtitle: Text(DateFormat('yyyy.MM.dd HH:mm').format(e.time)),
                              onTap: () {},
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
