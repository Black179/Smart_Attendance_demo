import requests

# Initialize the Railway database
url = "https://smartattendancedemo-production.up.railway.app/init-db"

try:
    response = requests.post(url)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")
    
    if response.status_code == 200:
        print("✅ Database initialized successfully!")
    else:
        print("❌ Database initialization failed!")
        
except Exception as e:
    print(f"Error: {e}")
