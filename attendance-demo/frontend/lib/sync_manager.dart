import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

enum QueuedActionType {
  enroll,
  markAttendance,
  odRequest,
  heartbeat,
  attendanceUpdate,
}

class QueuedAction {
  final String id;
  final QueuedActionType type;
  final Map<String, dynamic> data;
  final String? filePath;
  final DateTime createdAt;
  final int retryCount;

  QueuedAction({
    required this.id,
    required this.type,
    required this.data,
    this.filePath,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'data': data,
    'filePath': filePath,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory QueuedAction.fromJson(Map<String, dynamic> json) => QueuedAction(
    id: json['id'],
    type: QueuedActionType.values.firstWhere((e) => e.name == json['type']),
    data: Map<String, dynamic>.from(json['data']),
    filePath: json['filePath'],
    createdAt: DateTime.parse(json['createdAt']),
    retryCount: json['retryCount'] ?? 0,
  );

  QueuedAction copyWith({
    String? id,
    QueuedActionType? type,
    Map<String, dynamic>? data,
    String? filePath,
    DateTime? createdAt,
    int? retryCount,
  }) => QueuedAction(
    id: id ?? this.id,
    type: type ?? this.type,
    data: data ?? this.data,
    filePath: filePath ?? this.filePath,
    createdAt: createdAt ?? this.createdAt,
    retryCount: retryCount ?? this.retryCount,
  );
}

class SyncManager extends ChangeNotifier {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  bool _isOnline = false;
  bool _isSyncing = false;
  List<QueuedAction> _queuedActions = [];
  late Dio _dio;
  late Box<String> _queueBox;
  Directory? _offlineFilesDir;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get queuedCount => _queuedActions.length;
  List<QueuedAction> get queuedActions => List.unmodifiable(_queuedActions);

  Future<void> initialize(Dio dio) async {
    _dio = dio;
    // Configure Dio with auth interceptor
    AuthService.configureDio(_dio);
    // Initialize Hive box for queue
    _queueBox = await Hive.openBox<String>('sync_queue');
    
    // Create offline files directory (only on non-web platforms)
    if (!kIsWeb) {
      final appDir = await getApplicationDocumentsDirectory();
      _offlineFilesDir = Directory('${appDir.path}/offline_files');
      if (!await _offlineFilesDir!.exists()) {
        await _offlineFilesDir!.create(recursive: true);
      }
    }
    
    // Load queued actions from Hive
    await _loadQueuedActions();
    
    // Check initial connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    if (connectivityResults is List<ConnectivityResult>) {
      _updateConnectivityStatus(connectivityResults);
    } else {
      _updateConnectivityStatus([connectivityResults as ConnectivityResult]);
    }
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectivityStatus);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _updateConnectivityStatus(List<ConnectivityResult> results) {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;
    
    if (!wasOnline && _isOnline && _queuedActions.isNotEmpty) {
      // Connection restored and we have queued actions
      _syncQueuedActions();
    }
    
    notifyListeners();
  }

  Future<void> _loadQueuedActions() async {
    _queuedActions.clear();
    
    for (String key in _queueBox.keys) {
      try {
        final jsonString = _queueBox.get(key);
        if (jsonString != null) {
          final json = jsonDecode(jsonString);
          final action = QueuedAction.fromJson(json);
          _queuedActions.add(action);
        }
      } catch (e) {
        print('Error loading queued action $key: $e');
        // Remove corrupted entry
        await _queueBox.delete(key);
      }
    }
    
    // Sort by creation time
    _queuedActions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();
  }

  Future<String> _saveFileForOfflineSync(File file) async {
    try {
      if (kIsWeb) {
        // On web, we can't save files to disk, so we'll store the file path
        // and handle it differently during sync
        return file.path;
      }
      
      if (_offlineFilesDir == null) {
        return file.path; // Fallback if directory not initialized
      }
      
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final offlineFile = File('${_offlineFilesDir!.path}/$fileName');
      await file.copy(offlineFile.path);
      
      return offlineFile.path;
    } catch (e) {
      print('Error saving file for offline sync: $e');
      return '';
    }
  }

  Future<void> queueAction({
    required QueuedActionType type,
    required Map<String, dynamic> data,
    File? file,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    String? filePath;
    
    // Save file for offline if provided
    if (file != null) {
      final filename = '${type.name}_${id}_${file.path.split('/').last}';
      filePath = await _saveFileForOfflineSync(file);
    }
    
    final action = QueuedAction(
      id: id,
      type: type,
      data: data,
      filePath: filePath,
      createdAt: DateTime.now(),
    );
    
    // Save to Hive
    await _queueBox.put(action.id, jsonEncode(action.toJson()));
    
    // Add to memory
    _queuedActions.add(action);
    notifyListeners();
    
    // Try to sync immediately if online
    if (_isOnline) {
      _syncQueuedActions();
    }
  }

  Future<void> _syncQueuedActions() async {
    if (_isSyncing || _queuedActions.isEmpty) return;
    
    _isSyncing = true;
    notifyListeners();
    
    final actionsToSync = List<QueuedAction>.from(_queuedActions);
    
    for (final action in actionsToSync) {
      try {
        final success = await _syncSingleAction(action);
        
        if (success) {
          // Remove from queue
          await _removeFromQueue(action);
        } else {
          // Increment retry count
          final updatedAction = action.copyWith(retryCount: action.retryCount + 1);
          await _updateActionInQueue(action, updatedAction);
          
          // Stop syncing if too many retries
          if (updatedAction.retryCount >= 3) {
            print('Action ${action.id} failed after 3 retries, skipping');
            continue;
          }
        }
      } catch (e) {
        print('Error syncing action ${action.id}: $e');
      }
    }
    
    _isSyncing = false;
    notifyListeners();
  }

  Future<bool> _syncSingleAction(QueuedAction action) async {
    try {
      switch (action.type) {
        case QueuedActionType.enroll:
          return await _syncEnrollAction(action);
        case QueuedActionType.markAttendance:
          return await _syncMarkAttendanceAction(action);
        case QueuedActionType.odRequest:
          return await _syncODRequestAction(action);
        case QueuedActionType.heartbeat:
          return await _syncHeartbeatAction(action);
        case QueuedActionType.attendanceUpdate:
          return await _syncAttendanceUpdateAction(action);
      }
    } catch (e) {
      print('Error in _syncSingleAction: $e');
      return false;
    }
  }

  Future<bool> _syncEnrollAction(QueuedAction action) async {
    try {
      Map<String, dynamic> requestData = {
        'name': action.data['name'],
        'roll': action.data['roll'],
        'class_id': action.data['class_id'],
      };

      if (action.data['face_embedding'] != null) {
        requestData['face_embedding'] = action.data['face_embedding'];
      }

      final response = await _dio.post('/enroll', data: requestData);
      
      // Clean up offline file
      if (action.filePath != null && !kIsWeb) {
        final file = File(action.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _syncMarkAttendanceAction(QueuedAction action) async {
    try {
      final response = await _dio.post('/mark_attendance', data: action.data);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _syncODRequestAction(QueuedAction action) async {
    try {
      FormData formData = FormData.fromMap({
        'student_roll': action.data['student_roll'],
        'reason': action.data['reason'],
      });

      if (action.filePath != null) {
        if (kIsWeb) {
          // On web, we can't access files the same way
          // Skip file upload for web or handle differently
          print('Web file upload not supported for offline sync');
        } else {
          final file = File(action.filePath!);
          if (await file.exists()) {
            formData.files.add(MapEntry(
              'file',
              await MultipartFile.fromFile(file.path),
            ));
          }
        }
      }

      final response = await _dio.post('/od-request', data: formData);
      
      // Clean up offline file
      if (action.filePath != null && !kIsWeb) {
        final file = File(action.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _syncHeartbeatAction(QueuedAction action) async {
    try {
      final response = await _dio.post('/heartbeat', data: action.data);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _syncAttendanceUpdateAction(QueuedAction action) async {
    try {
      final response = await _dio.post('/attendance/update', data: action.data);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _removeFromQueue(QueuedAction action) async {
    await _queueBox.delete(action.id);
    _queuedActions.removeWhere((a) => a.id == action.id);
    notifyListeners();
  }

  Future<void> _updateActionInQueue(QueuedAction oldAction, QueuedAction newAction) async {
    await _queueBox.put(newAction.id, jsonEncode(newAction.toJson()));
    
    final index = _queuedActions.indexWhere((a) => a.id == oldAction.id);
    if (index != -1) {
      _queuedActions[index] = newAction;
      notifyListeners();
    }
  }

  Future<void> forceSyncNow() async {
    if (_isOnline) {
      await _syncQueuedActions();
    }
  }

  Future<void> clearQueue() async {
    // Clean up offline files
    for (final action in _queuedActions) {
      if (action.filePath != null) {
        final file = File(action.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    
    await _queueBox.clear();
    _queuedActions.clear();
    notifyListeners();
  }

  String getActionDescription(QueuedAction action) {
    switch (action.type) {
      case QueuedActionType.enroll:
        return 'Enroll ${action.data['name']} (${action.data['roll']})';
      case QueuedActionType.markAttendance:
        return 'Mark attendance for ${action.data['roll']}';
      case QueuedActionType.odRequest:
        return 'OD request from ${action.data['student_roll']}';
      case QueuedActionType.heartbeat:
        return 'Heartbeat from ${action.data['roll']}';
      case QueuedActionType.attendanceUpdate:
        return 'Update attendance for student ${action.data['student_id']}';
    }
  }
}
