import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'sync_manager.dart';
import 'main.dart';

class OfflineService {
  static Future<bool> enrollStudent({
    required BuildContext context,
    required String name,
    required String roll,
    required String classId,
    String? faceEmbedding,
  }) async {
    final syncManager = context.read<SyncManager>();
    
    if (syncManager.isOnline) {
      // Try direct submission first
      try {
        final appState = context.read<AppState>();
        Map<String, dynamic> requestData = {
          'name': name,
          'roll': roll,
          'class_id': classId,
        };

        if (faceEmbedding != null) {
          requestData['face_embedding'] = faceEmbedding;
        }

        final response = await appState.dio.post('/enroll', data: requestData);
        return response.statusCode == 200;
      } catch (e) {
        // Fall through to queue if online request fails
      }
    }
    
    // Queue for offline sync
    await syncManager.queueAction(
      type: QueuedActionType.enroll,
      data: {
        'name': name,
        'roll': roll,
        'class_id': classId,
        'face_embedding': faceEmbedding,
      },
    );
    
    return true; // Queued successfully
  }

  static Future<bool> markAttendance({
    required BuildContext context,
    required String roll,
    required String classId,
  }) async {
    final syncManager = context.read<SyncManager>();
    
    if (syncManager.isOnline) {
      try {
        final appState = context.read<AppState>();
        final response = await appState.dio.post('/mark_attendance', data: {
          'roll': roll,
          'class_id': classId,
        });
        return response.statusCode == 200;
      } catch (e) {
        // Fall through to queue
      }
    }
    
    await syncManager.queueAction(
      type: QueuedActionType.markAttendance,
      data: {
        'roll': roll,
        'class_id': classId,
      },
    );
    
    return true;
  }

  static Future<bool> submitODRequest({
    required BuildContext context,
    required String studentRoll,
    required String reason,
    File? file,
  }) async {
    final syncManager = context.read<SyncManager>();
    
    if (syncManager.isOnline) {
      try {
        final appState = context.read<AppState>();
        FormData formData = FormData.fromMap({
          'student_roll': studentRoll,
          'reason': reason,
        });

        if (file != null) {
          formData.files.add(MapEntry(
            'file',
            await MultipartFile.fromFile(file.path),
          ));
        }

        final response = await appState.dio.post('/od-request', data: formData);
        return response.statusCode == 200;
      } catch (e) {
        // Fall through to queue
      }
    }
    
    await syncManager.queueAction(
      type: QueuedActionType.odRequest,
      data: {
        'student_roll': studentRoll,
        'reason': reason,
      },
      file: file,
    );
    
    return true;
  }

  static Future<bool> sendHeartbeat({
    required BuildContext context,
    required String roll,
    required String classId,
    required String timestamp,
  }) async {
    final syncManager = context.read<SyncManager>();
    
    if (syncManager.isOnline) {
      try {
        final appState = context.read<AppState>();
        final response = await appState.dio.post('/heartbeat', data: {
          'roll': roll,
          'class_id': classId,
          'timestamp': timestamp,
        });
        return response.statusCode == 200;
      } catch (e) {
        // Fall through to queue
      }
    }
    
    await syncManager.queueAction(
      type: QueuedActionType.heartbeat,
      data: {
        'roll': roll,
        'class_id': classId,
        'timestamp': timestamp,
      },
    );
    
    return true;
  }

  static Future<bool> updateAttendance({
    required BuildContext context,
    required int studentId,
    required String classId,
    required String status,
    String? reason,
  }) async {
    final syncManager = context.read<SyncManager>();
    
    if (syncManager.isOnline) {
      try {
        final appState = context.read<AppState>();
        final response = await appState.dio.post('/attendance/update', data: {
          'student_id': studentId,
          'class_id': classId,
          'status': status,
          'reason': reason ?? '',
        });
        return response.statusCode == 200;
      } catch (e) {
        // Fall through to queue
      }
    }
    
    await syncManager.queueAction(
      type: QueuedActionType.attendanceUpdate,
      data: {
        'student_id': studentId,
        'class_id': classId,
        'status': status,
        'reason': reason ?? '',
      },
    );
    
    return true;
  }

  static void showOfflineMessage(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.offline_bolt, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$action queued for sync when online'),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
