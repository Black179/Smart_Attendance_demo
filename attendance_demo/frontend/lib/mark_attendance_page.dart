import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'main.dart';
import 'offline_service.dart';
import 'sync_manager.dart';

class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  final _formKey = GlobalKey<FormState>();
  final _rollController = TextEditingController();
  final _classIdController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _rollController.dispose();
    _classIdController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    try {
      final box = await Hive.openBox('students');
      final keys = box.keys.toList();
      
      if (keys.isNotEmpty) {
        // Load the first student's data as default
        final firstStudentKey = keys.first;
        final studentData = box.get(firstStudentKey);
        
        if (studentData != null) {
          setState(() {
            _rollController.text = studentData['roll'] ?? '';
            _classIdController.text = studentData['class_id'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Failed to load saved data: $e');
    }
  }

  Future<void> _markAttendance() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await OfflineService.markAttendance(
        context: context,
        roll: _rollController.text.trim(),
        classId: _classIdController.text.trim(),
      );

      if (success) {
        final syncManager = context.read<SyncManager>();
        if (syncManager.isOnline) {
          _showSnackBar('Attendance marked successfully!', Colors.green);
        } else {
          OfflineService.showOfflineMessage(context, 'Attendance marking');
        }
        
        // Save attendance status locally
        final box = await Hive.openBox('attendance_data');
        final today = DateTime.now().toIso8601String().split('T')[0];
        await box.put('${_rollController.text.trim()}_$today', 'Present');
        
        // Clear form
        _rollController.clear();
        _classIdController.clear();
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAttendanceLocally() async {
    try {
      final box = await Hive.openBox('attendance');
      final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
      
      final attendanceKey = '${_rollController.text.trim()}_$today';
      final attendanceData = {
        'roll': _rollController.text.trim(),
        'class_id': _classIdController.text.trim(),
        'date': today,
        'status': 'Present',
        'marked_at': DateTime.now().toIso8601String(),
      };
      
      await box.put(attendanceKey, attendanceData);
    } catch (e) {
      print('Failed to save attendance locally: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              const Text(
                'Mark Your Attendance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Today: ${DateTime.now().toString().split(' ')[0]}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Roll number field
              TextFormField(
                controller: _rollController,
                decoration: const InputDecoration(
                  labelText: 'Roll Number',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your roll number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Class ID field
              TextFormField(
                controller: _classIdController,
                decoration: const InputDecoration(
                  labelText: 'Class ID',
                  prefixIcon: Icon(Icons.class_),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your class ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              
              // Mark attendance button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _markAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Marking Attendance...'),
                          ],
                        )
                      : const Text(
                          'Mark Present',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Info card
              Card(
                color: Colors.blue.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Make sure you are in the correct class\n'
                        '• Attendance can only be marked once per day\n'
                        '• Contact your teacher if you face any issues',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
