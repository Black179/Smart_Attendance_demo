import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'main.dart';
import 'offline_service.dart';
import 'sync_manager.dart';

class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({super.key});

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  final _classIdController = TextEditingController();
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _presentStudents = [];
  List<Map<String, dynamic>> _absentStudents = [];
  List<Map<String, dynamic>> _pendingStudents = [];
  bool _isLoading = false;
  String? _currentClassId;
  String? _currentDate;

  @override
  void dispose() {
    _classIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchAttendance() async {
    if (_classIdController.text.trim().isEmpty) {
      _showSnackBar('Please enter a class ID', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _currentClassId = _classIdController.text.trim();
    });

    try {
      final appState = context.read<AppState>();
      
      final response = await appState.dio.get(
        '/class/${_classIdController.text.trim()}/attendance',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final attendanceList = List<Map<String, dynamic>>.from(data['attendance']);
        
        setState(() {
          _allStudents = attendanceList;
          _currentDate = data['date'];
          _groupStudentsByStatus();
        });
        
        _showSnackBar('Attendance data loaded successfully!', Colors.green);
      }
    } on DioException catch (e) {
      String errorMessage = 'Failed to fetch attendance';
      if (e.response?.data != null && e.response!.data['detail'] != null) {
        errorMessage = e.response!.data['detail'];
      }
      _showSnackBar(errorMessage, Colors.red);
    } catch (e) {
      _showSnackBar('Unexpected error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _groupStudentsByStatus() {
    _presentStudents = _allStudents.where((s) => s['status'] == 'Present').toList();
    _absentStudents = _allStudents.where((s) => s['status'] == 'Absent').toList();
    _pendingStudents = _allStudents.where((s) => s['status'] == 'Pending').toList();
  }

  Future<void> _updateAttendance(int studentId, String newStatus, String? reason) async {
    try {
      final success = await OfflineService.updateAttendance(
        context: context,
        studentId: studentId,
        classId: _classIdController.text.trim(),
        status: newStatus,
        reason: reason,
      );

      if (success) {
        final syncManager = context.read<SyncManager>();
        if (syncManager.isOnline) {
          _showSnackBar('Attendance updated successfully!', Colors.green);
        } else {
          OfflineService.showOfflineMessage(context, 'Attendance update');
        }
        _fetchAttendance(); // Refresh the list
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  void _showEditDialog(Map<String, dynamic> student) {
    String selectedStatus = student['status'];
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Attendance - ${student['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Roll: ${student['roll']}'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: ['Present', 'Absent', 'Pending'].map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
              onChanged: (value) {
                selectedStatus = value!;
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateAttendance(student['id'], selectedStatus, reasonController.text);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
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
        title: const Text('Class Attendance'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (_currentClassId != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchAttendance,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search section
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                TextField(
                  controller: _classIdController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Class ID',
                    prefixIcon: Icon(Icons.class_),
                    border: OutlineInputBorder(),
                    hintText: 'e.g., CS-A, CS-B',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _fetchAttendance,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isLoading ? 'Loading...' : 'Load Attendance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Results section
          Expanded(
            child: _allStudents.isEmpty
                ? _buildEmptyState()
                : _buildAttendanceSections(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No class data loaded',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a class ID and tap "Load Attendance" to manage attendance',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSections() {
    return Column(
      children: [
        // Header with class info
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.green.shade50,
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'Class: $_currentClassId',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const Spacer(),
              Text(
                'Date: $_currentDate',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),
        ),
        
        // Statistics
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard('Total', _allStudents.length.toString(), Colors.blue),
              _buildStatCard('Present', _presentStudents.length.toString(), Colors.green),
              _buildStatCard('Absent', _absentStudents.length.toString(), Colors.red),
              _buildStatCard('Pending', _pendingStudents.length.toString(), Colors.orange),
            ],
          ),
        ),
        
        // Attendance sections
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  labelColor: Colors.green,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.green,
                  tabs: [
                    Tab(text: 'Present', icon: Icon(Icons.check_circle)),
                    Tab(text: 'Absent', icon: Icon(Icons.cancel)),
                    Tab(text: 'Pending', icon: Icon(Icons.schedule)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildStudentList(_presentStudents, Colors.green),
                      _buildStudentList(_absentStudents, Colors.red),
                      _buildStudentList(_pendingStudents, Colors.orange),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList(List<Map<String, dynamic>> students, Color color) {
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No students in this category',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Text(
                student['name'][0].toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              student['name'],
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text('Roll: ${student['roll']}'),
            trailing: ElevatedButton.icon(
              onPressed: () => _showEditDialog(student),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 32),
              ),
            ),
          ),
        );
      },
    );
  }
}
