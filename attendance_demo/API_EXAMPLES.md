# API Examples & Testing

This document provides curl examples and Postman-style requests for testing the SmartAttendance API endpoints.

## Base URL
```
http://localhost:8000
```

## Authentication Examples

### 1. Student Login
```bash
curl -X POST "http://localhost:8000/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "role": "student",
    "roll": "CS001"
  }'
```

**Response:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "token_type": "bearer",
  "role": "student",
  "user_id": 1,
  "roll": "CS001"
}
```

### 2. Teacher Login
```bash
curl -X POST "http://localhost:8000/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "role": "teacher",
    "username": "teacher",
    "password": "teacher123"
  }'
```

### 3. Driver Login
```bash
curl -X POST "http://localhost:8000/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "role": "driver",
    "username": "driver",
    "password": "driver123"
  }'
```

## Student Management

### 4. Enroll Student (with face embedding)
```bash
curl -X POST "http://localhost:8000/enroll" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "name=John Doe" \
  -F "roll=CS004" \
  -F "class_id=CS_2024" \
  -F 'face_embedding=[0.1,0.2,0.3,0.4,0.5]'
```

### 5. Face Recognition
```bash
curl -X POST "http://localhost:8000/recognize" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "embedding": [0.1, 0.2, 0.3, 0.4, 0.5],
    "class_id": "CS_2024"
  }'
```

## Attendance Management

### 6. Mark Attendance
```bash
curl -X POST "http://localhost:8000/mark_attendance" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "student_roll=CS001" \
  -F "class_id=CS_2024"
```

### 7. Get Class Attendance
```bash
curl -X GET "http://localhost:8000/class/CS_2024/attendance" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### 8. Update Attendance Status
```bash
curl -X POST "http://localhost:8000/attendance/update" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "student_id": 1,
    "class_id": "CS_2024",
    "status": "Present",
    "reason": "Updated by teacher"
  }'
```

## OD Request Management

### 9. Submit OD Request
```bash
curl -X POST "http://localhost:8000/od-request" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "student_roll=CS001" \
  -F "reason=Medical appointment" \
  -F "file=@medical_certificate.pdf"
```

### 10. Get Pending OD Requests
```bash
curl -X GET "http://localhost:8000/od-requests" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### 11. Approve/Reject OD Request
```bash
curl -X POST "http://localhost:8000/od-approve" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "od_id": 1,
    "status": "Approved",
    "comment": "Valid medical reason"
  }'
```

## Utility Endpoints

### 12. Health Check
```bash
curl -X GET "http://localhost:8000/healthcheck"
```

**Response:**
```json
{
  "status": "healthy"
}
```

### 13. API Documentation
Visit: `http://localhost:8000/docs`

## Postman Collection

### Import Instructions
1. Open Postman
2. Click "Import" → "Raw Text"
3. Paste the following JSON:

```json
{
  "info": {
    "name": "SmartAttendance API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "variable": [
    {
      "key": "baseUrl",
      "value": "http://localhost:8000"
    },
    {
      "key": "token",
      "value": ""
    }
  ],
  "item": [
    {
      "name": "Authentication",
      "item": [
        {
          "name": "Student Login",
          "request": {
            "method": "POST",
            "header": [
              {
                "key": "Content-Type",
                "value": "application/json"
              }
            ],
            "body": {
              "mode": "raw",
              "raw": "{\n  \"role\": \"student\",\n  \"roll\": \"CS001\"\n}"
            },
            "url": {
              "raw": "{{baseUrl}}/auth/login",
              "host": ["{{baseUrl}}"],
              "path": ["auth", "login"]
            }
          }
        }
      ]
    }
  ]
}
```

## Testing Workflow

### Complete Test Sequence
1. **Login as Teacher** → Get JWT token
2. **Enroll Student** → Create new student with face embedding
3. **Login as Student** → Get student JWT token
4. **Mark Attendance** → Record attendance
5. **Login as Teacher** → Switch back to teacher
6. **View Attendance** → Check recorded attendance
7. **Submit OD Request** → As student
8. **Approve OD** → As teacher

### Error Responses

**401 Unauthorized:**
```json
{
  "detail": "Invalid authentication credentials"
}
```

**400 Bad Request:**
```json
{
  "detail": "Roll number required for students"
}
```

**404 Not Found:**
```json
{
  "detail": "Student not found"
}
```
