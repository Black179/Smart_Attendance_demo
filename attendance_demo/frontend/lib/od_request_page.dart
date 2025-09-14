import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'main.dart';
import 'offline_service.dart';
import 'sync_manager.dart';

class ODRequestPage extends StatefulWidget {
  const ODRequestPage({super.key});

  @override
  State<ODRequestPage> createState() => _ODRequestPageState();
}

class _ODRequestPageState extends State<ODRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _rollController = TextEditingController();
  final _reasonController = TextEditingController();
  
  File? _selectedFile;
  String? _selectedFileName;
  bool _isLoading = false;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadStudentRoll();
  }

  @override
  void dispose() {
    _rollController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentRoll() async {
    try {
      final box = await Hive.openBox('student_data');
      final roll = box.get('roll');
      if (roll != null) {
        _rollController.text = roll;
      }
    } catch (e) {
      print('Error loading student roll: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          if (!kIsWeb) {
            _selectedFile = File(pickedFile.path);
          }
          _selectedFileName = pickedFile.name;
        });
        _showSnackBar('File selected: ${pickedFile.name}', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error selecting file: $e', Colors.red);
    }
  }

  Future<void> _submitODRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_rollController.text.trim().isEmpty) {
      _showSnackBar('Please enter your roll number', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      File? requestFile;
      if (_selectedFile != null && !kIsWeb) {
        requestFile = _selectedFile;
      }
      
      final success = await OfflineService.submitODRequest(
        context: context,
        studentRoll: _rollController.text.trim(),
        reason: _reasonController.text.trim(),
        file: requestFile,
      );

      if (success) {
        final syncManager = context.read<SyncManager>();
        if (syncManager.isOnline) {
          _showSnackBar('OD request submitted successfully!', Colors.green);
        } else {
          OfflineService.showOfflineMessage(context, 'OD request');
        }
        
        // Save to local storage for history
        final box = await Hive.openBox('od_requests');
        final requests = box.get('requests', defaultValue: <Map>[]).cast<Map>();
        requests.add({
          'id': DateTime.now().millisecondsSinceEpoch,
          'roll': _rollController.text.trim(),
          'reason': _reasonController.text.trim(),
          'status': 'Pending',
          'submitted_at': DateTime.now().toIso8601String(),
          'file_name': _selectedFileName,
        });
        await box.put('requests', requests);
        
        // Clear form
        _reasonController.clear();
        setState(() {
          _selectedFile = null;
          _selectedFileName = null;
        });
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
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
        title: const Text('Submit OD Request'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment,
                      size: 48,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'On Duty (OD) Request',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submit your request for official duty leave',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Roll Number Field
              TextFormField(
                controller: _rollController,
                decoration: const InputDecoration(
                  labelText: 'Roll Number',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                  hintText: 'Enter your roll number',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your roll number';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Reason Field
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for OD',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                  hintText: 'Explain the reason for your OD request',
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the reason for OD';
                  }
                  if (value.trim().length < 10) {
                    return 'Reason must be at least 10 characters long';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // File Upload Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.attach_file, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Supporting Document (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload any supporting document (image only)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_selectedFileName != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedFileName!,
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red.shade600, size: 20),
                              onPressed: () {
                                setState(() {
                                  _selectedFile = null;
                                  _selectedFileName = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.upload_file),
                        label: Text(_selectedFileName == null ? 'Choose File' : 'Change File'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitODRequest,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isLoading ? 'Submitting...' : 'Submit OD Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your OD request will be reviewed by the teacher. You will be notified once it\'s approved or rejected.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
