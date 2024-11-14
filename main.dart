import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Báo Thức App',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: AlarmPage(onThemeToggle: _toggleTheme),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Alarm {
  final String id;
  final TimeOfDay time;
  bool isActive;

  Alarm({required this.id, required this.time, this.isActive = true});
}

class AlarmPage extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const AlarmPage({super.key, required this.onThemeToggle});

  @override
  _AlarmPageState createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  late FlutterTts _flutterTts; // Thêm đối tượng FlutterTts
  List<Alarm> alarms = [];
  int alarmCount = 0;
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _notificationMessage;
  String _currentTime = '';
  late Timer _timer; // Timer để cập nhật thời gian thực

  @override
  void initState() {
    super.initState();
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    _flutterTts = FlutterTts(); // Khởi tạo FlutterTts
    _initializeNotifications();
    tz.initializeTimeZones();
    _startClock(); // Bắt đầu cập nhật thời gian thực
  }

  // Bắt đầu cập nhật thời gian thực
  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      setState(() {
        _currentTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      });

      // Kiểm tra báo thức
      _checkAlarms(now);
    });
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  void _checkAlarms(DateTime currentTime) {
    for (var alarm in alarms) {
      final alarmTime = DateTime(currentTime.year, currentTime.month,
          currentTime.day, alarm.time.hour, alarm.time.minute);

      // Nếu báo thức đến, hiển thị thông báo và phát âm
      if (alarm.isActive &&
          alarmTime.isBefore(currentTime) &&
          alarmTime.add(const Duration(minutes: 1)).isAfter(currentTime)) {
        _onAlarmTriggered(alarm.id);
      }
    }
  }

  Future<void> _onAlarmTriggered(String alarmId) async {
    // Phát âm thông báo khi đến giờ báo thức
    await _flutterTts.speak("Đến giờ báo thức!");

    setState(() {
      _notificationMessage = "Báo thức: $alarmId đã được kích hoạt!";
    });
  }

  Future<void> _setAlarm() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    String alarmId = 'alarm_${alarmCount++}';
    alarms.add(Alarm(id: alarmId, time: _selectedTime));

    // Kiểm tra nếu báo thức đã đến và phát âm nếu cần
    if (scheduledTime.isBefore(now.add(const Duration(minutes: 1)))) {
      await _onAlarmTriggered(
          alarmId); // Phát âm ngay khi cài lại báo thức đã qua
    }

    await _notificationsPlugin.zonedSchedule(
      alarmId.hashCode,
      'Báo Thức',
      'Đến giờ báo thức!',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'your_channel_id',
          'your_channel_name',
          channelDescription: 'Mô tả kênh của bạn',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    setState(() {});
  }

  void _toggleAlarm(Alarm alarm) {
    setState(() {
      alarm.isActive = !alarm.isActive;
      if (!alarm.isActive) {
        _cancelAlarm(alarm);
      } else {
        _setAlarm();
      }
    });
  }

  Future<void> _cancelAlarm(Alarm alarm) async {
    await _notificationsPlugin.cancel(alarm.id.hashCode);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _deleteAlarm(Alarm alarm) {
    setState(() {
      _cancelAlarm(alarm);
      alarms.remove(alarm);
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Hủy bỏ Timer khi không cần thiết
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo Thức App'),
      ),
      body: Container(
        decoration: const BoxDecoration(),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Thời gian hiện tại: $_currentTime'),
                  ElevatedButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (time != null) {
                        setState(() {
                          _selectedTime = time;
                        });
                      }
                    },
                    child: const Text('Chọn Thời Gian'),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _setAlarm,
              child: const Text('Đặt Báo Thức'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: alarms.length,
                itemBuilder: (context, index) {
                  final alarm = alarms[index];
                  return ListTile(
                    title: Text('Báo thức: ${_formatTime(alarm.time)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: alarm.isActive,
                          onChanged: (value) => _toggleAlarm(alarm),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteAlarm(alarm),
                        ),
                      ],
                    ),
                    onLongPress: () => _deleteAlarm(alarm),
                  );
                },
              ),
            ),
            if (_notificationMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _notificationMessage!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: widget.onThemeToggle,
        child: const Icon(Icons.brightness_6),
      ),
    );
  }
}
