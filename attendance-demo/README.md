# SmartAttendance System

A comprehensive attendance management system with JWT authentication, face recognition capabilities, and offline sync support. Built with FastAPI backend and Flutter frontend.

## 🚀 Quick Start Guide

### Prerequisites
- Python 3.8+ with pip
- Flutter SDK 3.0+
- Chrome browser (for web testing)

### Backend Setup (FastAPI)

1. **Navigate to backend directory:**
   ```bash
   cd backend
   ```

2. **Install Python dependencies:**
   ```bash
   pip install fastapi uvicorn sqlmodel PyJWT passlib[bcrypt] python-multipart
   ```

3. **Start the backend server:**
   ```bash
   python main.py
   ```
   
   ✅ **Backend running at:** `http://localhost:8000`
   - 📚 **API Documentation:** `http://localhost:8000/docs`
   - 🔍 **Health Check:** `http://localhost:8000/healthcheck`

### Frontend Setup (Flutter)

1. **Navigate to frontend directory:**
   ```bash
   cd frontend
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run Flutter app (Web):**
   ```bash
   flutter run -d chrome --web-port 8080
   ```

4. **Run Flutter app (Android Emulator):**
   ```bash
   flutter run -d android
   ```

   ⚠️ **Important for Android Emulator:** 
   - Use `10.0.2.2:8000` instead of `localhost:8000` for API calls
   - Update `baseUrl` in `auth_service.dart` and `sync_manager.dart`

### 📱 Emulator Configuration

**For Android Emulator:**
```dart
// In auth_service.dart and other API files, change:
'http://localhost:8000/auth/login'
// To:
'http://10.0.2.2:8000/auth/login'
```

**For iOS Simulator:**
```dart
// Use localhost (works directly):
'http://localhost:8000/auth/login'
```

## 🎯 Features

### 🔐 Authentication & Security
- JWT token-based authentication
- Role-based access (Student/Teacher/Driver)
- Secure token storage with `flutter_secure_storage`
- Protected API endpoints

### 📊 Backend (FastAPI)
- RESTful API with automatic documentation
- SQLite database with SQLModel ORM
- Face embedding storage and recognition
- File upload support for OD requests
- CORS middleware enabled
- Data seeding with sample students

### 📱 Frontend (Flutter)
- Cross-platform (Web, Android, iOS)
- Material Design 3 UI
- JWT authentication flow
- Face recognition demo page
- Offline sync with queue management
- Real-time connectivity monitoring
- Camera integration for photos
- BLE heartbeat simulation

### 🔄 Offline Support
- Automatic action queuing when offline
- Sync when connectivity restored
- File storage for offline uploads
- Visual sync status indicators

## 🔑 Demo Credentials

### Student Login
- **Role:** Student
- **Roll Numbers:** `CS001`, `CS002`, `CS003`

### Teacher Login
- **Role:** Teacher
- **Username:** `teacher`
- **Password:** `teacher123`

### Driver Login
- **Role:** Driver
- **Username:** `driver`
- **Password:** `driver123`

## 📋 Demo Checklist

Follow this checklist to test all major features:

### 1. ✅ Student Enrollment
- [ ] Login as teacher
- [ ] Navigate to enrollment page
- [ ] Capture/upload student photo
- [ ] Fill student details (name, roll, class)
- [ ] Submit enrollment
- [ ] Verify face embedding is stored

### 2. ✅ Mark Attendance
- [ ] Login as student
- [ ] Navigate to mark attendance
- [ ] Select class and submit
- [ ] Verify attendance recorded in database

### 3. ✅ Teacher View Attendance
- [ ] Login as teacher
- [ ] Navigate to attendance history
- [ ] View class attendance records
- [ ] Update attendance status if needed

### 4. ✅ OD Request Flow
- [ ] Login as student
- [ ] Submit OD request with reason
- [ ] Upload supporting document (optional)
- [ ] Login as teacher
- [ ] Review pending OD requests
- [ ] Approve/reject with comments

### 5. ✅ Offline Queue Test
- [ ] Disconnect internet
- [ ] Perform actions (enrollment, attendance)
- [ ] Observe offline queue status
- [ ] Reconnect internet
- [ ] Verify automatic sync

### 6. ✅ Face Recognition Demo
- [ ] Login as student
- [ ] Navigate to face recognition page
- [ ] Capture photo for recognition
- [ ] View similarity scores and matches

## 🔧 API Endpoints

### Authentication
- `POST /auth/login` - User login with role-based credentials

### Student Management
- `POST /enroll` - Enroll student with face embedding
- `POST /recognize` - Face recognition with similarity matching

### Attendance
- `POST /mark_attendance` - Mark student attendance
- `GET /class/{class_id}/attendance` - Get class attendance
- `POST /attendance/update` - Update attendance status

### OD Requests
- `POST /od-request` - Submit OD request
- `GET /od-requests` - Get pending OD requests
- `POST /od-approve` - Approve/reject OD request

### Utility
- `GET /` - Root endpoint
- `GET /healthcheck` - Health check

## 🧪 Testing & Integration

### Integration Test Script
Run the comprehensive test suite to verify all functionality:

```bash
cd attendance-demo
python test_integration.py
```

This script tests:
- Backend health and connectivity
- Authentication for all roles
- Student enrollment with face embeddings
- Attendance marking and retrieval
- OD request submission and approval
- Face recognition functionality
- Attendance status updates

### API Testing
See `API_EXAMPLES.md` for detailed curl examples and Postman collection for manual API testing.

## 🚀 Next Steps & Production Readiness

### Immediate Enhancements
1. **Real Face Recognition Model**
   - Replace stub embedding generation with actual TensorFlow Lite model
   - Implement proper face detection and feature extraction
   - Add face quality validation

2. **BLE Integration**
   - Implement actual BLE peripheral for student devices
   - Add proximity-based attendance validation
   - Create heartbeat monitoring system

3. **Security Hardening**
   - Add HTTPS/TLS encryption
   - Implement rate limiting
   - Add audit logging for all actions
   - Use environment variables for all secrets

### Advanced Features
4. **Database Optimization**
   - Migrate from SQLite to PostgreSQL for production
   - Add database indexing for performance
   - Implement data backup and recovery

5. **UI/UX Improvements**
   - Add dark mode support
   - Implement push notifications
   - Create admin dashboard for system monitoring
   - Add data visualization and analytics

6. **Scalability & Deployment**
   - Containerize with Docker
   - Add CI/CD pipeline
   - Implement horizontal scaling
   - Add monitoring and logging (Prometheus, Grafana)

### Architecture Considerations
- **Microservices**: Split into authentication, attendance, and face recognition services
- **Message Queue**: Add Redis/RabbitMQ for async processing
- **CDN**: Use cloud storage for face images and documents
- **Load Balancer**: Add nginx for high availability

## 📞 Support & Documentation

- **API Documentation**: Visit `http://localhost:8000/docs` when backend is running
- **Integration Tests**: Run `python test_integration.py` for system validation
- **Manual Testing**: Use examples in `API_EXAMPLES.md`

## 🎯 Demo Ready

The system is now fully functional with:
- ✅ JWT authentication for all roles
- ✅ Complete attendance workflow
- ✅ OD request management
- ✅ Offline sync capabilities
- ✅ Face recognition demo
- ✅ Comprehensive testing suite
- ✅ Production-ready documentation

Ready for demonstration and further development!
