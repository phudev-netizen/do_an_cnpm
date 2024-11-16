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
  late FlutterTts _flutterTts;
  List<Alarm> alarms = [];
  int alarmCount = 0;
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _notificationMessage;
  String _currentTime = '';
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    _flutterTts = FlutterTts();
    _initializeNotifications();
    tz.initializeTimeZones();
    _startClock();
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      setState(() {
        _currentTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      });
      _checkAlarms(now);
    });
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  void _checkAlarms(DateTime currentTime) {
    for (var alarm in alarms) {
      final alarmTime = DateTime(currentTime.year, currentTime.month,
          currentTime.day, alarm.time.hour, alarm.time.minute);

      if (alarm.isActive &&
          alarmTime.isBefore(currentTime) &&
          alarmTime.add(const Duration(minutes: 1)).isAfter(currentTime)) {
        _onAlarmTriggered(alarm.id);
      }
    }
  }

  Future<void> _onAlarmTriggered(String alarmId) async {
    await _flutterTts.speak("Đến giờ báo thức!");
    setState(() {
      _notificationMessage = "Báo thức: $alarmId đã được kích hoạt!";
    });
    _showAlarmOptionsDialog(alarmId);
  }

  Future<void> _showAlarmOptionsDialog(String alarmId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Báo Thức Đến Giờ'),
          content: const Text('Chọn một trong các tùy chọn:'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _turnOffAlarm(alarmId);
              },
              child: const Text('Bỏ qua'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _snoozeAlarm(alarmId);
              },
              child: const Text('Báo lại'),
            ),
          ],
        );
      },
    );
  }

  void _snoozeAlarm(String alarmId) {
    final alarm = alarms.firstWhere((alarm) => alarm.id == alarmId);
    setState(() {
      alarm.isActive = false;
    });

    final now = DateTime.now();
    TimeOfDay newTime =
        TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5)));
    alarms.add(Alarm(id: alarmId, time: newTime));
  }

  void _turnOffAlarm(String alarmId) {
    final alarmToTurnOff = alarms.firstWhere(
      (alarm) => alarm.id == alarmId,
      orElse: () => Alarm(id: '', time: TimeOfDay.now(), isActive: false),
    );

    if (alarmToTurnOff.id.isNotEmpty) {
      setState(() {
        alarmToTurnOff.isActive = false;
        alarms.removeWhere((alarm) => alarm.id == alarmId);
      });
    }
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

    if (scheduledTime.isBefore(now.add(const Duration(minutes: 1)))) {
      await _onAlarmTriggered(alarmId);
    }

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
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo Thức App'),
      ),
      body: Column(
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
      floatingActionButton: FloatingActionButton(
        onPressed: widget.onThemeToggle,
        child: const Icon(Icons.brightness_6),
      ),
    );
  }
}
