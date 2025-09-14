import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'jwt_token';
  static const String _roleKey = 'user_role';
  static const String _userIdKey = 'user_id';
  static const String _rollKey = 'user_roll';

  static String? _currentToken;
  static String? _currentRole;
  static int? _currentUserId;
  static String? _currentRoll;

  // Getters
  static String? get currentToken => _currentToken;
  static String? get currentRole => _currentRole;
  static int? get currentUserId => _currentUserId;
  static String? get currentRoll => _currentRoll;
  static bool get isLoggedIn => _currentToken != null;

  // Initialize auth service - load stored token
  static Future<void> initialize() async {
    try {
      _currentToken = await _storage.read(key: _tokenKey);
      _currentRole = await _storage.read(key: _roleKey);
      final userIdStr = await _storage.read(key: _userIdKey);
      _currentUserId = userIdStr != null ? int.tryParse(userIdStr) : null;
      _currentRoll = await _storage.read(key: _rollKey);
      
      if (kDebugMode) {
        print('AuthService: Loaded token: ${_currentToken != null ? "Yes" : "No"}');
        print('AuthService: Current role: $_currentRole');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AuthService: Error loading stored auth: $e');
      }
    }
  }

  // Login method
  static Future<Map<String, dynamic>> login({
    required String role,
    String? roll,
    String? username,
    String? password,
  }) async {
    final dio = Dio();
    
    // Configure base URL
    dio.options.baseUrl = 'https://smartattendancedemo-production.up.railway.app';
    
    // Add timeout configuration
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 10);
    
    if (kDebugMode) {
      print('AuthService: Attempting login for role: $role');
      print('AuthService: Backend URL: ${dio.options.baseUrl}/auth/login');
    }
    
    try {
      final response = await dio.post(
        '/auth/login',
        data: {
          'role': role,
          if (roll != null) 'roll': roll,
          if (username != null) 'username': username,
          if (password != null) 'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        // Store authentication data
        _currentToken = data['access_token'];
        _currentRole = data['role'];
        _currentUserId = data['user_id'];
        _currentRoll = data['roll'];

        // Persist to secure storage
        await _storage.write(key: _tokenKey, value: _currentToken);
        await _storage.write(key: _roleKey, value: _currentRole);
        if (_currentUserId != null) {
          await _storage.write(key: _userIdKey, value: _currentUserId.toString());
        }
        if (_currentRoll != null) {
          await _storage.write(key: _rollKey, value: _currentRoll);
        }

        if (kDebugMode) {
          print('AuthService: Login successful for role: $_currentRole');
        }

        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': 'Login failed'};
      }
    } on DioException catch (e) {
      String errorMessage = 'Login failed';
      if (kDebugMode) {
        print('AuthService: DioException - ${e.type}: ${e.message}');
        print('AuthService: Response: ${e.response?.data}');
      }
      
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Connection timeout. Please check if the backend server is running.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Cannot connect to server. Please check your internet connection and try again.';
      } else if (e.response?.data != null && e.response!.data['detail'] != null) {
        errorMessage = e.response!.data['detail'];
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      if (kDebugMode) {
        print('AuthService: General error: $e');
      }
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Logout method
  static Future<void> logout() async {
    _currentToken = null;
    _currentRole = null;
    _currentUserId = null;
    _currentRoll = null;

    // Clear secure storage
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _rollKey);

    if (kDebugMode) {
      print('AuthService: Logged out successfully');
    }
  }

  // Get authorization header for API requests
  static Map<String, String> getAuthHeaders() {
    if (_currentToken != null) {
      return {
        'Authorization': 'Bearer $_currentToken',
        'Content-Type': 'application/json',
      };
    }
    return {'Content-Type': 'application/json'};
  }

  // Configure Dio with auth interceptor
  static void configureDio(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_currentToken != null) {
            options.headers['Authorization'] = 'Bearer $_currentToken';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Token expired or invalid - logout
            logout();
          }
          handler.next(error);
        },
      ),
    );
  }
}
