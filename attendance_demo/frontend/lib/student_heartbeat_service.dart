import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import 'main.dart';
import 'offline_service.dart';

class StudentHeartbeatService extends StatefulWidget {
  const StudentHeartbeatService({super.key});

  @override
  State<StudentHeartbeatService> createState() => _StudentHeartbeatServiceState();
}

class _StudentHeartbeatServiceState extends State<StudentHeartbeatService> {
  bool _heartbeatEnabled = false;
  Timer? _heartbeatTimer;
  String? _studentRoll;
  String? _classId;
  DateTime? _lastHeartbeat;
  int _heartbeatCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  @override
  void dispose() {
    _stopHeartbeat();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    try {
      final box = await Hive.openBox('student_data');
      setState(() {
        _studentRoll = box.get('roll');
        _classId = box.get('class_id', defaultValue: 'CS-A'); // Default class
      });
    } catch (e) {
      print('Error loading student data: $e');
    }
  }

  void _toggleHeartbeat(bool enabled) {
    setState(() {
      _heartbeatEnabled = enabled;
    });

    if (enabled) {
      _startHeartbeat();
    } else {
      _stopHeartbeat();
    }
  }

  void _startHeartbeat() {
    if (_studentRoll == null) {
      _showSnackBar('Please set your roll number first', Colors.red);
      setState(() {
        _heartbeatEnabled = false;
      });
      return;
    }

    // Send initial heartbeat
    _sendHeartbeat();

    // Set up periodic timer (every 5 seconds)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _sendHeartbeat();
    });

    _showSnackBar('BLE heartbeat simulation started', Colors.green);
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _showSnackBar('BLE heartbeat simulation stopped', Colors.orange);
  }

  Future<void> _sendHeartbeat() async {
    if (_studentRoll == null || _classId == null) return;

    try {
      final timestamp = DateTime.now().toUtc().toIso8601String();
      
      final success = await OfflineService.sendHeartbeat(
        context: context,
        roll: _studentRoll!,
        classId: _classId!,
        timestamp: timestamp,
      );

      if (success) {
        setState(() {
          _lastHeartbeat = DateTime.now();
          _heartbeatCount++;
        });
        print('Heartbeat sent successfully: $_heartbeatCount');
      }
    } catch (e) {
      print('Unexpected heartbeat error: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Never';
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Heartbeat Demo'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Demo Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'BLE Heartbeat Simulation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This demo simulates BLE presence by sending periodic heartbeats to the backend every 5 seconds. In a real implementation, this would be replaced by actual BLE peripheral advertising.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Student Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.badge, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text('Roll: ${_studentRoll ?? "Not set"}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.class_, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text('Class: ${_classId ?? "Not set"}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Heartbeat Control
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'BLE Heartbeat Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _heartbeatEnabled,
                          onChanged: _toggleHeartbeat,
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _heartbeatEnabled ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _heartbeatEnabled ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: _heartbeatEnabled ? Colors.green : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Statistics
            if (_heartbeatEnabled || _heartbeatCount > 0)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Heartbeat Statistics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatCard('Total Sent', _heartbeatCount.toString(), Colors.blue),
                          _buildStatCard('Last Sent', _formatDateTime(_lastHeartbeat), Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Real BLE Implementation Notes
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.code, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Real BLE Implementation TODO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'For production implementation, replace this heartbeat simulation with:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• BLE Peripheral mode advertising\n'
                    '• Custom service UUID for attendance\n'
                    '• Student ID in advertisement data\n'
                    '• Platform-specific implementations:\n'
                    '  - Android: BluetoothLeAdvertiser\n'
                    '  - iOS: CBPeripheralManager\n'
                    '• Driver app scans and detects students\n'
                    '• Automatic attendance marking based on proximity',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade700,
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

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/*
=== REAL BLE PERIPHERAL IMPLEMENTATION PLACEHOLDER ===

For a production BLE attendance system, implement the following:

1. BLE Peripheral Advertising (Student Side):
```dart
// TODO: Implement BLE peripheral advertising
class BLEPeripheralService {
  static const String ATTENDANCE_SERVICE_UUID = "12345678-1234-1234-1234-123456789abc";
  static const String STUDENT_CHARACTERISTIC_UUID = "87654321-4321-4321-4321-cba987654321";
  
  Future<void> startAdvertising(String studentId) async {
    // Platform-specific implementation needed
    if (Platform.isAndroid) {
      // Use BluetoothLeAdvertiser
      // Configure advertisement data with student ID
      // Start advertising with custom service UUID
    } else if (Platform.isIOS) {
      // Use CBPeripheralManager
      // Configure peripheral with student characteristic
      // Start advertising
    }
  }
  
  Future<void> stopAdvertising() async {
    // Stop BLE advertising
  }
}
```

2. BLE Central Scanning (Driver Side):
```dart
// TODO: Enhanced BLE scanning for attendance
class AttendanceBLEScanner {
  Future<List<StudentDevice>> scanForStudents() async {
    // Scan specifically for attendance service UUID
    // Filter devices by service UUID
    // Extract student IDs from advertisement data
    // Return list of detected students with RSSI
  }
  
  Future<void> markAttendanceForDetectedStudents(List<StudentDevice> students) async {
    // Automatically mark attendance for detected students
    // POST to backend with student IDs and detection timestamp
    // Handle proximity-based filtering (RSSI threshold)
  }
}
```

3. Platform-Specific Considerations:
- Android: Requires BLUETOOTH_ADVERTISE permission (API 31+)
- iOS: Requires NSBluetoothPeripheralUsageDescription
- Background advertising limitations on both platforms
- Power management and battery optimization
- Range and reliability considerations

4. Security Considerations:
- Encrypt student IDs in advertisement data
- Implement rolling codes to prevent replay attacks
- Add authentication mechanisms
- Consider privacy implications of BLE broadcasting

This heartbeat simulation provides the same backend integration
while avoiding platform-specific BLE peripheral complexities.
*/
