import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:my_app/volunteer/services/request.dart';
import 'package:my_app/volunteer/screens/home_screen.dart';

class CalendarScreen extends StatefulWidget {
  final String? userId;
  const CalendarScreen({super.key, required this.userId});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  // ***** 여기를 수정합니다: _selectedDay를 non-nullable로 선언합니다. *****
  late DateTime _selectedDay; // late 키워드를 사용하여 initState에서 초기화됨을 명시

  Map<DateTime, List<Request>> _events = {};
  List<Request> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay; // initState에서 _selectedDay를 반드시 초기화합니다.
  }

  List<Request> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents = _getEventsForDay(selectedDay); // 선택된 날짜의 이벤트 업데이트
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '경북 경산시',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            Icon(Icons.keyboard_arrow_down, color: Colors.black),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              /* TODO: 검색 기능 */
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {
              /* TODO: 알림 기능 */
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              /* TODO: 메뉴 기능 */
            },
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('requests')
                .where('requesterId', isEqualTo: widget.userId)
                .where('status', whereIn: ['waiting', 'accepted'])
                .orderBy('status')
                .orderBy('time', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                print("CalendarScreen StreamBuilder 오류: ${snapshot.error}");
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('일정 정보를 불러오는 데 실패했습니다: ${snapshot.error}', textAlign: TextAlign.center),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '일정이 비어있어요',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HomeScreen(userId: widget.userId),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('일정 찾으러 가기', style: TextStyle(fontSize: 16)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final allRequests = snapshot.data!.docs
                  .map((doc) => Request.fromFirestore(doc))
                  .where((req) => req.time.isAfter(DateTime.now().subtract(const Duration(days: 1))))
                  .toList();

              Request? nearestRequest;
              if (allRequests.isNotEmpty) {
                nearestRequest = allRequests.reduce((a, b) =>
                    a.time.difference(DateTime.now()).abs() <
                            b.time.difference(DateTime.now()).abs()
                        ? a
                        : b);
              }

              _events.clear();
              for (var req in allRequests) {
                final normalizedDay = DateTime.utc(req.time.year, req.time.month, req.time.day);
                _events.putIfAbsent(normalizedDay, () => []).add(req);
              }
              // ***** 여기도 수정합니다: _selectedDay가 이미 초기화되었으므로 바로 사용 *****
              _selectedEvents = _getEventsForDay(_selectedDay); // _selectedDay는 더 이상 null이 아님


              return Column(
                children: [
                  if (nearestRequest != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 0),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.blue[100],
                                ),
                                child: const Center(
                                  child: Icon(Icons.map, color: Colors.blue, size: 30),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${nearestRequest.locationFrom}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${DateFormat('yyyy.MM.dd').format(nearestRequest.time)}',
                                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_calculateDistance(nearestRequest.locationFrom)}km',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const Icon(Icons.arrow_forward),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16.0),

                  TableCalendar<Request>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: _calendarFormat,
                    eventLoader: _getEventsForDay,
                    onDaySelected: _onDaySelected,
                    onFormatChanged: (format) {
                      if (_calendarFormat != format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      }
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextFormatter: (date, locale) => DateFormat('yyyy.MM').format(date),
                      titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
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
                      weekendTextStyle: TextStyle(color: Colors.red[600]),
                      defaultTextStyle: const TextStyle(color: Colors.black87),
                    ),
                    locale: 'ko_KR',
                    daysOfWeekHeight: 20.0,
                    rowHeight: 45.0,
                  ),
                  const SizedBox(height: 8.0),
                  Expanded(
                    child: _selectedEvents.isEmpty
                        ? const Center(
                            child: Text('선택된 날짜에 일정이 없습니다.'),
                          )
                        : ListView.builder(
                            itemCount: _selectedEvents.length,
                            itemBuilder: (context, index) {
                              final event = _selectedEvents[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  leading: const Icon(Icons.event),
                                  title: Text('${event.locationFrom} -> ${event.locationTo}'),
                                  subtitle: Text(DateFormat('yyyy.MM.dd HH:mm').format(event.time)),
                                  //trailing: Text('${event.points} pt'),
                                  onTap: () {
                                    print('일정 상세 보기: ${event.id}');
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _calculateDistance(String location) {
    return '3.5';
  }
}