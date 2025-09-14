import requests
import json

# Test the deployed API - replace with your Railway URL
deployed_url = "https://smartattendancedemo-production.up.railway.app"  # Update this with your actual Railway URL

def test_deployed_api():
    print("Testing deployed API health...")
    try:
        response = requests.get(f"{deployed_url}/")
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error connecting to deployed API: {e}")
        return False

def test_deployed_login():
    print("\nTesting deployed student login...")
    data = {
        "role": "student",
        "roll": "CS001"
    }
    
    try:
        response = requests.post(f"{deployed_url}/auth/login", json=data)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        if response.status_code == 200:
            print("✅ Deployed login successful!")
        else:
            print("❌ Deployed login failed!")
        return response
    except Exception as e:
        print(f"Error: {e}")
        return None

if __name__ == "__main__":
    if test_deployed_api():
        test_deployed_login()
    else:
        print("Deployed API is not accessible")
