# CAKU OCR - Simple Upload Test
# Tes upload file sederhana

import requests
import sys

SERVER_URL = 'http://192.168.1.6:8000'
IMAGE_PATH = './uploads/struk-indmrt.jpg'

print("Testing file upload...")
print(f"Server: {SERVER_URL}")
print(f"Image: {IMAGE_PATH}")
print()

try:
    # IMPORTANT: Gunakan 'with' statement untuk handle file dengan benar
    with open(IMAGE_PATH, 'rb') as f:
        files = {
            'file': ('struk-indmrt.jpg', f, 'image/jpeg')
        }
        
        print("⏳ Uploading...")
        response = requests.post(
            f"{SERVER_URL}/predict",
            files=files,
            timeout=60
        )
        
        print(f"Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print("\n✅ SUCCESS!")
            print(f"Items: {data.get('items_count', 0)}")
            print(f"Total: Rp {data['totals']['total']:,.0f}")
            print(f"Time: {data['process_time_seconds']}s")
        else:
            print(f"\n❌ ERROR: {response.status_code}")
            print(response.json())

except FileNotFoundError:
    print(f"❌ File not found: {IMAGE_PATH}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Error: {str(e)}")
    sys.exit(1)
