import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'main.dart';
import 'face_embedding_service.dart';

class FaceRecognitionPage extends StatefulWidget {
  const FaceRecognitionPage({super.key});

  @override
  State<FaceRecognitionPage> createState() => _FaceRecognitionPageState();
}

class _FaceRecognitionPageState extends State<FaceRecognitionPage> {
  final _formKey = GlobalKey<FormState>();
  final _classIdController = TextEditingController();
  
  XFile? _capturedImage;
  bool _isLoading = false;
  Map<String, dynamic>? _recognitionResult;

  @override
  void dispose() {
    _classIdController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _capturedImage = image;
          _recognitionResult = null; // Clear previous results
        });
        _showSnackBar('Photo captured successfully!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Failed to capture photo: $e', Colors.red);
    }
  }

  Future<void> _recognizeFace() async {
    if (!_formKey.currentState!.validate() || _capturedImage == null) {
      _showSnackBar('Please capture a photo and enter class ID', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Extract face embedding
      final photoFile = File(_capturedImage!.path);
      _showSnackBar('Extracting face features...', Colors.blue);
      
      final embedding = await FaceEmbeddingService.extractEmbedding(photoFile);
      
      // Send recognition request
      final appState = context.read<AppState>();
      final response = await appState.dio.post('/recognize', data: {
        'embedding': embedding,
        'class_id': _classIdController.text.trim(),
      });

      if (response.statusCode == 200) {
        setState(() {
          _recognitionResult = response.data;
        });
        
        if (response.data['recognized'] == true) {
          _showSnackBar(
            'Student recognized: ${response.data['student_name']}', 
            Colors.green
          );
        } else {
          _showSnackBar('No matching student found', Colors.orange);
        }
      }
    } catch (e) {
      _showSnackBar('Recognition failed: $e', Colors.red);
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
        title: const Text('Face Recognition'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Face Recognition Demo',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Class ID input
              TextFormField(
                controller: _classIdController,
                decoration: const InputDecoration(
                  labelText: 'Class ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.class_),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter class ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Photo capture section
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _capturedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? Image.network(
                                _capturedImage!.path,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_capturedImage!.path),
                                fit: BoxFit.cover,
                              ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No photo captured'),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              
              // Capture button
              ElevatedButton.icon(
                onPressed: _capturePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              
              // Recognize button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _recognizeFace,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.face),
                label: Text(_isLoading ? 'Recognizing...' : 'Recognize Face'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 20),
              
              // Recognition results
              if (_recognitionResult != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recognition Result',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        if (_recognitionResult!['recognized'] == true) ...[
                          _buildResultRow('Student Name', _recognitionResult!['student_name']),
                          _buildResultRow('Roll Number', _recognitionResult!['roll']),
                          _buildResultRow('Student ID', _recognitionResult!['student_id'].toString()),
                          _buildResultRow(
                            'Similarity Score', 
                            '${(_recognitionResult!['similarity_score'] * 100).toStringAsFixed(1)}%'
                          ),
                        ] else ...[
                          const Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('No matching student found'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
