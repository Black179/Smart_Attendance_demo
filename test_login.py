import requests
import json

# Test the login endpoint
base_url = "http://localhost:8000"

def test_student_login():
    print("Testing student login...")
    data = {
        "role": "student",
        "roll": "CS001"
    }
    
    try:
        response = requests.post(f"{base_url}/auth/login", json=data)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        if response.status_code == 200:
            print("✅ Login successful!")
        else:
            print("❌ Login failed!")
        return response
    except Exception as e:
        print(f"Error: {e}")
        return None

def test_teacher_login():
    print("\nTesting teacher login...")
    data = {
        "role": "teacher",
        "username": "teacher",
        "password": "teacher123"
    }
    
    try:
        response = requests.post(f"{base_url}/auth/login", json=data)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        if response.status_code == 200:
            print("✅ Login successful!")
        else:
            print("❌ Login failed!")
        return response
    except Exception as e:
        print(f"Error: {e}")
        return None

def test_api_health():
    print("Testing API health...")
    try:
        response = requests.get(f"{base_url}/")
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        if response.status_code == 200:
            print("✅ Login successful!")
        else:
            print("❌ Login failed!")
        return response
    except Exception as e:
        print(f"Error connecting to API: {e}")
        return None

if __name__ == "__main__":
    # First test if API is running
    health_response = test_api_health()
    
    if health_response and health_response.status_code == 200:
        # Test student login
        student_response = test_student_login()
        
        # Test teacher login
        teacher_response = test_teacher_login()
    else:
        print("API is not running or not accessible")
