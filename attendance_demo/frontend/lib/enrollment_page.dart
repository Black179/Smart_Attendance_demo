import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'main.dart';
import 'camera_page.dart';
import 'offline_service.dart';
import 'sync_manager.dart';
import 'face_embedding_service.dart';

class EnrollmentPage extends StatefulWidget {
  const EnrollmentPage({super.key});

  @override
  State<EnrollmentPage> createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _classIdController = TextEditingController();
  
  XFile? _capturedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _classIdController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    try {
      if (kIsWeb) {
        // For web, use image picker
        final XFile? image = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 800,
          maxHeight: 600,
          imageQuality: 80,
        );
        
        if (image != null) {
          setState(() {
            _capturedImage = image;
          });
          _showSnackBar('Photo captured successfully!', Colors.green);
        }
      } else {
        // For mobile, use custom camera page
        final String? imagePath = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (context) => const CameraPage()),
        );
        
        if (imagePath != null) {
          setState(() {
            _capturedImage = XFile(imagePath);
          });
          _showSnackBar('Photo captured successfully!', Colors.green);
        }
      }
    } catch (e) {
      _showSnackBar('Failed to capture photo: $e', Colors.red);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _capturedImage = image;
        });
        _showSnackBar('Photo selected successfully!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Failed to select photo: $e', Colors.red);
    }
  }

  Future<void> _submitEnrollment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? faceEmbedding;
      
      // Extract face embedding if photo is captured
      if (_capturedImage != null && !kIsWeb) {
        final photoFile = File(_capturedImage!.path);
        _showSnackBar('Extracting face features...', Colors.blue);
        
        final embedding = await FaceEmbeddingService.extractEmbedding(photoFile);
        faceEmbedding = jsonEncode(embedding);
        
        _showSnackBar('Face features extracted successfully!', Colors.green);
      }
      
      final success = await OfflineService.enrollStudent(
        context: context,
        name: _nameController.text.trim(),
        roll: _rollController.text.trim(),
        classId: _classIdController.text.trim(),
        faceEmbedding: faceEmbedding,
      );

      if (success) {
        final syncManager = context.read<SyncManager>();
        if (syncManager.isOnline) {
          _showSnackBar('Student enrolled successfully!', Colors.green);
        } else {
          OfflineService.showOfflineMessage(context, 'Enrollment');
        }
        
        // Save student data locally
        final box = await Hive.openBox('student_data');
        await box.put('name', _nameController.text.trim());
        await box.put('roll', _rollController.text.trim());
        await box.put('class_id', _classIdController.text.trim());
        
        // Clear form
        _nameController.clear();
        _rollController.clear();
        _classIdController.clear();
        setState(() {
          _capturedImage = null;
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

  Future<void> _saveStudentData() async {
    try {
      await Hive.initFlutter();
      final box = await Hive.openBox('students');
      
      final studentData = {
        'name': _nameController.text.trim(),
        'roll': _rollController.text.trim(),
        'class_id': _classIdController.text.trim(),
        'enrolled_at': DateTime.now().toIso8601String(),
      };
      
      await box.put(_rollController.text.trim(), studentData);
    } catch (e) {
      print('Failed to save student data: $e');
    }
  }

  void _clearForm() {
    _nameController.clear();
    _rollController.clear();
    _classIdController.clear();
    setState(() {
      _capturedImage = null;
    });
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
        title: const Text('Student Enrollment'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enroll New Student',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter student name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
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
                    return 'Please enter roll number';
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
                    return 'Please enter class ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Photo section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Student Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Photo preview
                    if (_capturedImage != null)
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: kIsWeb
                            ? FutureBuilder<Uint8List>(
                                future: _capturedImage!.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                              )
                            : Image.file(
                                File(_capturedImage!.path),
                                fit: BoxFit.cover,
                              ),
                      )
                    else
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No photo captured',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // Photo capture buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _capturePhoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Capture Photo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickFromGallery,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('From Gallery'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Enroll button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitEnrollment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
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
                            Text('Enrolling...'),
                          ],
                        )
                      : const Text(
                          'Enroll Student',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
