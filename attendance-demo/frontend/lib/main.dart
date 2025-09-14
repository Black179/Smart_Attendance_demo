import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'enrollment_page.dart';
import 'mark_attendance_page.dart';
import 'attendance_history_page.dart';
import 'teacher_attendance_page.dart';
import 'od_request_page.dart';
import 'teacher_od_requests_page.dart';
import 'od_history_page.dart';
import 'driver_ble_scanner_simple.dart';
import 'student_heartbeat_service.dart';
import 'sync_manager.dart';
import 'sync_status_widget.dart';
import 'face_recognition_page.dart';
import 'auth_service.dart';
import 'login_page.dart';

// Models
enum UserRole { student, teacher, driver }

class AppState extends ChangeNotifier {
  UserRole? _currentRole;
  late Dio _dio;
  late SyncManager _syncManager;

  AppState() {
    _dio = Dio();
    _syncManager = SyncManager();
    // Configure Dio with auth interceptor
    AuthService.configureDio(_dio);
  }

  UserRole? get currentRole => _currentRole;
  SyncManager get syncManager => _syncManager;
  Dio get dio => _dio;

  void _initializeDio() {
    _dio = Dio();
    
    // Configure base URL based on platform
    String baseUrl;
    if (kIsWeb) {
      baseUrl = 'http://127.0.0.1:8000';
    } else if (Platform.isAndroid) {
      baseUrl = 'http://10.0.2.2:8000'; // Android emulator
    } else {
      baseUrl = 'http://127.0.0.1:8000'; // iOS simulator, desktop
    }
    
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  Future<void> _initializeSyncManager() async {
    _syncManager = SyncManager();
    await _syncManager.initialize(_dio);
  }

  void setRole(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  void logout() {
    _currentRole = null;
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await AuthService.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppState()),
        ChangeNotifierProvider(create: (context) => SyncManager()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: AuthService.isLoggedIn ? '/main' : '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/main': (context) => const MainApp(),
      },
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine role from AuthService
    final role = AuthService.currentRole;
    
    if (role == 'student') {
      return const StudentHome();
    } else if (role == 'teacher') {
      return const TeacherHome();
    } else if (role == 'driver') {
      return const DriverHome();
    } else {
      // If no valid role, redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
  }
}

class RoleSelector extends StatelessWidget {
  const RoleSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Student Dashboard'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await AuthService.logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
        ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Select Your Role',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              _buildRoleCard(
                context,
                'Student',
                Icons.school,
                Colors.blue,
                UserRole.student,
              ),
              const SizedBox(height: 20),
              _buildRoleCard(
                context,
                'Teacher',
                Icons.person,
                Colors.green,
                UserRole.teacher,
              ),
              const SizedBox(height: 20),
              _buildRoleCard(
                context,
                'Driver',
                Icons.directions_bus,
                Colors.orange,
                UserRole.driver,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    UserRole role,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: ElevatedButton(
        onPressed: () {
          context.read<AppState>().setRole(role);
          _navigateToHome(context, role);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToHome(BuildContext context, UserRole role) {
    Widget destination;
    switch (role) {
      case UserRole.student:
        destination = const StudentHome();
        break;
      case UserRole.teacher:
        destination = const TeacherHome();
        break;
      case UserRole.driver:
        destination = const DriverHome();
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
  }
}

class StudentHome extends StatelessWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome, Student!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildFeatureCard(
                    'Mark Attendance',
                    Icons.check_circle,
                    Colors.green,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MarkAttendancePage()),
                    ),
                  ),
                  _buildFeatureCard(
                    'View Attendance',
                    Icons.list,
                    Colors.blue,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AttendanceHistoryPage()),
                    ),
                  ),
                  _buildFeatureCard(
                    'Enroll Student',
                    Icons.person_add,
                    Colors.orange,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EnrollmentPage()),
                    ),
                  ),
                  _buildFeatureCard(
                    'Submit OD Request',
                    Icons.assignment,
                    Colors.indigo,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ODRequestPage()),
                    ),
                  ),
                  _buildFeatureCard(
                    'My OD Requests',
                    Icons.history,
                    Colors.purple,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ODHistoryPage()),
                    ),
                  ),
                  _buildFeatureCard(
                    'BLE Heartbeat',
                    Icons.bluetooth,
                    Colors.purple,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StudentHeartbeatService()),
                    ),
                  ),
                  _buildFeatureCard(
                    'Face Recognition',
                    Icons.face,
                    Colors.deepPurple,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FaceRecognitionPage()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SyncStatusWidget(),
    );
  }

  Widget _buildFeatureCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 160,
          height: 120,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    context.read<AppState>().logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RoleSelector()),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class TeacherHome extends StatelessWidget {
  const TeacherHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome, Teacher!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildMenuTile(
                    'View Attendance History',
                    Icons.history,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AttendanceHistoryPage()),
                    ),
                  ),
                  _buildMenuTile(
                    'Submit OD Request',
                    Icons.assignment,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ODRequestPage()),
                    ),
                  ),
                  _buildMenuTile(
                    'My OD Requests',
                    Icons.history,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ODHistoryPage()),
                    ),
                  ),
                  _buildMenuTile(
                    'Enroll Students',
                    Icons.person_add,
                    () => _showSnackBar(context, 'Enroll Students clicked'),
                  ),
                  _buildMenuTile(
                    'Review OD Requests',
                    Icons.assignment_turned_in,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TeacherODRequestsPage()),
                    ),
                  ),
                  _buildMenuTile(
                    'BLE Device Scanner',
                    Icons.bluetooth_searching,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DriverBLEScanner()),
                    ),
                  ),
                  _buildMenuTile(
                    'Reports',
                    Icons.analytics,
                    () => _showSnackBar(context, 'Reports clicked'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SyncStatusWidget(),
    );
  }

  Widget _buildMenuTile(String title, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  void _logout(BuildContext context) {
    context.read<AppState>().logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RoleSelector()),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class DriverHome extends StatelessWidget {
  const DriverHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome, Driver!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Column(
                children: [
                  _buildStatusCard('Bus Status', 'Active', Colors.green),
                  const SizedBox(height: 16),
                  _buildStatusCard('Route', 'Route A - Campus', Colors.blue),
                  const SizedBox(height: 16),
                  _buildStatusCard('Students Onboard', '12', Colors.orange),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildActionButton(
                          'Start Route',
                          Icons.play_arrow,
                          Colors.green,
                          () => _showSnackBar(context, 'Route Started'),
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          'Mark Student Pickup',
                          Icons.person_add,
                          Colors.blue,
                          () => _showSnackBar(context, 'Student Pickup'),
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          'Emergency Alert',
                          Icons.warning,
                          Colors.red,
                          () => _showSnackBar(context, 'Emergency Alert Sent'),
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          'End Route',
                          Icons.stop,
                          Colors.grey,
                          () => _showSnackBar(context, 'Route Ended'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    context.read<AppState>().logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RoleSelector()),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
