#!/usr/bin/env python3
"""
SmartAttendance Integration Test Script

This script tests the complete workflow of the SmartAttendance system:
1. Database seeding with sample data
2. Authentication flow for all roles
3. Student enrollment with face embeddings
4. Attendance marking and retrieval
5. OD request submission and approval
6. Face recognition testing

Usage:
    python test_integration.py
"""

import requests
import json
import time
import random
from typing import Dict, Any, Optional

# Configuration
BASE_URL = "http://localhost:8000"
TEST_STUDENT_ROLL = "TEST001"
TEST_CLASS_ID = "TEST_CLASS_2024"

class SmartAttendanceTestSuite:
    def __init__(self):
        self.base_url = BASE_URL
        self.tokens = {}
        self.test_data = {}
        
    def log(self, message: str, level: str = "INFO"):
        """Log test messages with timestamp"""
        timestamp = time.strftime("%H:%M:%S")
        print(f"[{timestamp}] {level}: {message}")
        
    def make_request(self, method: str, endpoint: str, token: Optional[str] = None, 
                    data: Optional[Dict] = None, files: Optional[Dict] = None) -> requests.Response:
        """Make HTTP request with optional authentication"""
        url = f"{self.base_url}{endpoint}"
        headers = {}
        
        if token:
            headers["Authorization"] = f"Bearer {token}"
            
        if method.upper() == "GET":
            response = requests.get(url, headers=headers)
        elif method.upper() == "POST":
            if files:
                response = requests.post(url, headers=headers, data=data, files=files)
            elif data:
                headers["Content-Type"] = "application/json"
                response = requests.post(url, headers=headers, json=data)
            else:
                response = requests.post(url, headers=headers)
        else:
            raise ValueError(f"Unsupported method: {method}")
            
        return response
        
    def test_health_check(self) -> bool:
        """Test if the backend is running"""
        self.log("Testing health check...")
        try:
            response = self.make_request("GET", "/healthcheck")
            if response.status_code == 200:
                self.log("✅ Backend is healthy")
                return True
            else:
                self.log(f"❌ Health check failed: {response.status_code}")
                return False
        except requests.exceptions.ConnectionError:
            self.log("❌ Cannot connect to backend. Is it running?")
            return False
            
    def test_authentication(self) -> bool:
        """Test authentication for all roles"""
        self.log("Testing authentication...")
        
        # Test student login
        student_data = {"role": "student", "roll": "CS001"}
        response = self.make_request("POST", "/auth/login", data=student_data)
        
        if response.status_code == 200:
            self.tokens["student"] = response.json()["access_token"]
            self.log("✅ Student login successful")
        else:
            self.log(f"❌ Student login failed: {response.text}")
            return False
            
        # Test teacher login
        teacher_data = {"role": "teacher", "username": "teacher", "password": "teacher123"}
        response = self.make_request("POST", "/auth/login", data=teacher_data)
        
        if response.status_code == 200:
            self.tokens["teacher"] = response.json()["access_token"]
            self.log("✅ Teacher login successful")
        else:
            self.log(f"❌ Teacher login failed: {response.text}")
            return False
            
        # Test driver login
        driver_data = {"role": "driver", "username": "driver", "password": "driver123"}
        response = self.make_request("POST", "/auth/login", data=driver_data)
        
        if response.status_code == 200:
            self.tokens["driver"] = response.json()["access_token"]
            self.log("✅ Driver login successful")
        else:
            self.log(f"❌ Driver login failed: {response.text}")
            return False
            
        return True
        
    def generate_face_embedding(self) -> list:
        """Generate a random face embedding for testing"""
        return [random.uniform(-1, 1) for _ in range(512)]
        
    def test_student_enrollment(self) -> bool:
        """Test student enrollment with face embedding"""
        self.log("Testing student enrollment...")
        
        enrollment_data = {
            "name": "Test Student",
            "roll": TEST_STUDENT_ROLL,
            "class_id": TEST_CLASS_ID,
            "face_embedding": json.dumps(self.generate_face_embedding())
        }
        
        response = self.make_request("POST", "/enroll", 
                                   token=self.tokens["teacher"], 
                                   data=enrollment_data)
        
        if response.status_code == 200:
            self.test_data["enrolled_student"] = response.json()
            self.log("✅ Student enrollment successful")
            return True
        else:
            self.log(f"❌ Student enrollment failed: {response.text}")
            return False
            
    def test_attendance_marking(self) -> bool:
        """Test attendance marking"""
        self.log("Testing attendance marking...")
        
        attendance_data = {
            "student_roll": TEST_STUDENT_ROLL,
            "class_id": TEST_CLASS_ID
        }
        
        response = self.make_request("POST", "/mark_attendance",
                                   token=self.tokens["student"],
                                   data=attendance_data)
        
        if response.status_code == 200:
            self.test_data["attendance"] = response.json()
            self.log("✅ Attendance marking successful")
            return True
        else:
            self.log(f"❌ Attendance marking failed: {response.text}")
            return False
            
    def test_attendance_retrieval(self) -> bool:
        """Test attendance retrieval"""
        self.log("Testing attendance retrieval...")
        
        response = self.make_request("GET", f"/class/{TEST_CLASS_ID}/attendance",
                                   token=self.tokens["teacher"])
        
        if response.status_code == 200:
            attendance_records = response.json()
            self.log(f"✅ Retrieved {len(attendance_records)} attendance records")
            return True
        else:
            self.log(f"❌ Attendance retrieval failed: {response.text}")
            return False
            
    def test_od_request_flow(self) -> bool:
        """Test OD request submission and approval"""
        self.log("Testing OD request flow...")
        
        # Submit OD request
        od_data = {
            "student_roll": TEST_STUDENT_ROLL,
            "reason": "Medical appointment - Integration test"
        }
        
        response = self.make_request("POST", "/od-request",
                                   token=self.tokens["student"],
                                   data=od_data)
        
        if response.status_code != 200:
            self.log(f"❌ OD request submission failed: {response.text}")
            return False
            
        od_request = response.json()
        self.log("✅ OD request submitted successfully")
        
        # Get pending OD requests
        response = self.make_request("GET", "/od-requests",
                                   token=self.tokens["teacher"])
        
        if response.status_code != 200:
            self.log(f"❌ OD request retrieval failed: {response.text}")
            return False
            
        od_requests = response.json()
        self.log(f"✅ Retrieved {len(od_requests)} pending OD requests")
        
        # Approve the OD request
        approval_data = {
            "od_id": od_request["id"],
            "status": "Approved",
            "comment": "Integration test approval"
        }
        
        response = self.make_request("POST", "/od-approve",
                                   token=self.tokens["teacher"],
                                   data=approval_data)
        
        if response.status_code == 200:
            self.log("✅ OD request approval successful")
            return True
        else:
            self.log(f"❌ OD request approval failed: {response.text}")
            return False
            
    def test_face_recognition(self) -> bool:
        """Test face recognition functionality"""
        self.log("Testing face recognition...")
        
        # Generate a test embedding
        test_embedding = self.generate_face_embedding()
        
        recognition_data = {
            "embedding": test_embedding,
            "class_id": TEST_CLASS_ID
        }
        
        response = self.make_request("POST", "/recognize",
                                   token=self.tokens["student"],
                                   data=recognition_data)
        
        if response.status_code == 200:
            results = response.json()
            self.log(f"✅ Face recognition completed. Found {len(results)} matches")
            return True
        else:
            self.log(f"❌ Face recognition failed: {response.text}")
            return False
            
    def test_attendance_update(self) -> bool:
        """Test attendance status update"""
        self.log("Testing attendance update...")
        
        # First, get the student ID from enrollment
        if "enrolled_student" not in self.test_data:
            self.log("❌ No enrolled student data available")
            return False
            
        student_id = self.test_data["enrolled_student"]["id"]
        
        update_data = {
            "student_id": student_id,
            "class_id": TEST_CLASS_ID,
            "status": "Present",
            "reason": "Updated via integration test"
        }
        
        response = self.make_request("POST", "/attendance/update",
                                   token=self.tokens["teacher"],
                                   data=update_data)
        
        if response.status_code == 200:
            self.log("✅ Attendance update successful")
            return True
        else:
            self.log(f"❌ Attendance update failed: {response.text}")
            return False
            
    def run_all_tests(self) -> bool:
        """Run the complete test suite"""
        self.log("🚀 Starting SmartAttendance Integration Tests")
        self.log("=" * 50)
        
        tests = [
            ("Health Check", self.test_health_check),
            ("Authentication", self.test_authentication),
            ("Student Enrollment", self.test_student_enrollment),
            ("Attendance Marking", self.test_attendance_marking),
            ("Attendance Retrieval", self.test_attendance_retrieval),
            ("Attendance Update", self.test_attendance_update),
            ("OD Request Flow", self.test_od_request_flow),
            ("Face Recognition", self.test_face_recognition),
        ]
        
        passed = 0
        total = len(tests)
        
        for test_name, test_func in tests:
            self.log(f"\n🧪 Running: {test_name}")
            try:
                if test_func():
                    passed += 1
                else:
                    self.log(f"❌ {test_name} FAILED", "ERROR")
            except Exception as e:
                self.log(f"❌ {test_name} ERROR: {str(e)}", "ERROR")
                
        self.log("\n" + "=" * 50)
        self.log(f"📊 Test Results: {passed}/{total} tests passed")
        
        if passed == total:
            self.log("🎉 All tests passed! System is working correctly.", "SUCCESS")
            return True
        else:
            self.log(f"⚠️  {total - passed} tests failed. Check the logs above.", "WARNING")
            return False
            
    def cleanup(self):
        """Clean up test data (optional)"""
        self.log("🧹 Cleaning up test data...")
        # Note: In a real scenario, you might want to clean up the test student
        # For this demo, we'll leave the data for manual inspection
        
def main():
    """Main test runner"""
    print("SmartAttendance Integration Test Suite")
    print("=====================================")
    print(f"Testing backend at: {BASE_URL}")
    print("Make sure the backend is running before starting tests.\n")
    
    # Wait for user confirmation
    input("Press Enter to start tests...")
    
    test_suite = SmartAttendanceTestSuite()
    
    try:
        success = test_suite.run_all_tests()
        test_suite.cleanup()
        
        if success:
            print("\n✅ Integration tests completed successfully!")
            print("The SmartAttendance system is ready for demo.")
        else:
            print("\n❌ Some tests failed. Please check the backend logs.")
            
    except KeyboardInterrupt:
        print("\n⏹️  Tests interrupted by user.")
    except Exception as e:
        print(f"\n💥 Unexpected error: {str(e)}")
        
if __name__ == "__main__":
    main()
