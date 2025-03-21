import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> onDidReceiveNotification(
      NotificationResponse notificationResponse) async {
    print("Notification received");
  }

  static Future<void> init() async {
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings("@mipmap/ic_launcher");
    const DarwinInitializationSettings iOSInitializationSettings =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidInitializationSettings,
      iOS: iOSInitializationSettings,
    );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotification,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showInstantNotification(String title, String body) async {
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_notification_channel_id',
          'Instant Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails());

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'instant_notification',
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  await NotificationService.init(); // Initialize Notification Service
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Face & CO Monitoring',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return MonitoringScreen();
  }
}

class MonitoringScreen extends StatefulWidget {
  @override
  _MonitoringScreenState createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final DatabaseReference _ppmRef =
      FirebaseDatabase.instance.ref('/MQ7_CO_PPM'); // Database path
  final CollectionReference faceDetectionData =
      FirebaseFirestore.instance.collection('face_detection_data');

  double? _ppmValue; // Variable to store the PPM value
  String? _faceDetectionTimestamp; // Timestamp from Firestore
  int? _detectedFaces; // Number of detected faces
  String _currentTime = ""; // Variable to store the current time
  Timer? _timer;

  // Set to track shown notifications
  final Set<String> _shownNotifications = {};

  @override
  void initState() {
    super.initState();

    // Listen for changes in the database (CO PPM level)
    _ppmRef.onValue.listen((event) {
      final value = event.snapshot.value;
      setState(() {
        _ppmValue = value != null ? double.parse(value.toString()) : null;
      });

      if (_ppmValue != null &&
          _ppmValue! >= 0 &&
          _ppmValue! <= 10 &&
          (_detectedFaces ?? 0) > 0) {
        _showNotificationOnce(
            "There's Person left behind in the Car",
            "CO Level: ${_ppmValue!.toStringAsFixed(2)} PPM with ${_detectedFaces!} face(s) detected.",
            "person_left");
      }

      // Check if both PPM > 30 and face > 0 to send notification
      if (_ppmValue != null &&
          _ppmValue! > 10 &&
          _ppmValue! <= 30 &&
          (_detectedFaces ?? 0) > 0) {
        _showNotificationOnce(
            "Warning Gas Level Increase",
            "CO Level: ${_ppmValue!.toStringAsFixed(2)} PPM with ${_detectedFaces!} face(s) detected.",
            "gas_level_increase");
      }

      if (_ppmValue != null &&
          _ppmValue! > 30 &&
          _ppmValue! <= 50 &&
          (_detectedFaces ?? 0) > 0) {
        NotificationService.showInstantNotification("Gas Level Dangerous",
            "CO Level: ${_ppmValue!.toStringAsFixed(2)} PPM with ${_detectedFaces!} face(s) detected.");
      }

      if (_ppmValue != null && _ppmValue! > 50 && (_detectedFaces ?? 0) > 0) {
        NotificationService.showInstantNotification("Open Window",
            "CO Level: ${_ppmValue!.toStringAsFixed(2)} PPM with ${_detectedFaces!} face(s) detected.");
      }
    });

    // Fetch data from Firestore (Face detection data)
    faceDetectionData.doc('latest_detection').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _faceDetectionTimestamp = data['timestamp'] ?? 'N/A';
          _detectedFaces = data['detected_faces'] ?? 0;
        });

        if (_detectedFaces! > 0 &&
            _ppmValue != null &&
            _ppmValue! >= 0 &&
            _ppmValue! <= 10) {
          _showNotificationOnce(
              "There's Person left behind in the Car",
              "CO Level: ${_ppmValue!.toStringAsFixed(2)} PPM with ${_detectedFaces!} face(s) detected.",
              "person_left");
        }
        // Additional check for CO level
        if (_detectedFaces! > 0 &&
            _ppmValue != null &&
            _ppmValue! > 10 &&
            _ppmValue! <= 30) {
          _showNotificationOnce(
              "Warning Gas Level Increase",
              "CO Level: ${_ppmValue!.toStringAsFixed(2)} PPM with ${_detectedFaces!} face(s) detected.",
              "gas_level_increase");
        }

        if (_detectedFaces! > 0 &&
            _ppmValue != null &&
            _ppmValue! > 30 &&
            _ppmValue! <= 50) {
          NotificationService.showInstantNotification("Gas Level Dangerous",
              "CO Level: ${_ppmValue!.toStringAsFixed(2)} PPM with ${_detectedFaces!} face(s) detected.");
        }

        if (_detectedFaces! > 0 && _ppmValue != null && _ppmValue! > 50) {
          NotificationService.showInstantNotification("Open Window",
              "CO Level: ${_ppmValue!.toStringAsFixed(2)} PPM with ${_detectedFaces!} face(s) detected.");
        }
      }
    });

    // Start timer to update the current time
    _updateTime();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  void _showNotificationOnce(String title, String body, String category) {
    if (!_shownNotifications.contains(category)) {
      NotificationService.showInstantNotification(title, body);
      _shownNotifications.add(category);
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    });
  }

  Color getTextColor(double ppmValue) {
    if (ppmValue < 11) {
      return Colors.green;
    } else if (ppmValue >= 11 && ppmValue <= 20) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FaCo',
          style: TextStyle(
              fontSize: 30, fontWeight: FontWeight.bold), // Make the text bold
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text(
                        'CO PPM Level:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      _ppmValue != null
                          ? Text(
                              _ppmValue!.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 50,
                                fontWeight: FontWeight.bold,
                                color: getTextColor(_ppmValue!),
                              ),
                            )
                          : const CircularProgressIndicator(),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'Faces Detected:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      _detectedFaces != null
                          ? Text(
                              '$_detectedFaces',
                              style: TextStyle(
                                fontSize: 50,
                                fontWeight: FontWeight.bold,
                                color: _detectedFaces! > 0
                                    ? Colors.blue
                                    : Colors.black,
                              ),
                            )
                          : const CircularProgressIndicator(),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _faceDetectionTimestamp != null
                  ? Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Last Detection: ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.bold, // Bold style for label
                              color: Colors.black, // Color for the label part
                            ),
                          ),
                          TextSpan(
                            text: '$_faceDetectionTimestamp',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.bold, // Bold style for timestamp
                              color:
                                  Colors.purple, // Color for the timestamp part
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Text(
                      'Fetching Face Detection Data...',
                      style:
                          TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
