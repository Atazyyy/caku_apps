"""
Test Script untuk CAKU OCR Server v4
Test dengan receipt image lokal
"""

import os
import sys
import requests
import json
from pathlib import Path

# Configuration
SERVER_URL = "http://192.168.1.6:8000"  # Sesuaikan IP
TEST_IMAGE = "./uploads/struk-indmrt.jpg"

def test_health():
    """Test health endpoint"""
    print("\n" + "="*80)
    print("🏥 TEST: Health Check")
    print("="*80)
    
    try:
        response = requests.get(f"{SERVER_URL}/health")
        print(f"✅ Status: {response.status_code}")
        print(json.dumps(response.json(), indent=2))
        return True
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_config():
    """Test config endpoint"""
    print("\n" + "="*80)
    print("⚙️  TEST: Config")
    print("="*80)
    
    try:
        response = requests.get(f"{SERVER_URL}/config")
        print(f"✅ Status: {response.status_code}")
        config = response.json()
        print(f"YOLO Available: {config.get('yolo_available')}")
        print(f"YOLO Model: {config.get('yolo_model')}")
        print(f"OCR Regions: {config.get('ocr_regions')}")
        return True
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_predict(image_path: str):
    """Test predict endpoint"""
    print("\n" + "="*80)
    print("📸 TEST: OCR Prediction")
    print("="*80)
    
    if not os.path.exists(image_path):
        print(f"❌ Image not found: {image_path}")
        return False
    
    print(f"📄 Testing with: {image_path}")
    
    try:
        with open(image_path, 'rb') as f:
            files = {'file': f}
            response = requests.post(f"{SERVER_URL}/predict", files=files)
        
        print(f"✅ Status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            
            # Pretty print hasil
            print("\n📊 RESULT:")
            print("-" * 80)
            print(f"Status: {result.get('status')}")
            print(f"Filename: {result.get('filename')}")
            print(f"Process Time: {result.get('process_time_seconds')}s")
            print(f"Confidence Level: {result.get('confidence_level')}")
            print(f"Average Confidence: {result.get('average_confidence')}")
            
            print("\n🏪 MERCHANT INFO:")
            merchant = result.get('merchant_info', {})
            print(f"  Name: {merchant.get('name')}")
            print(f"  Address: {merchant.get('address')}")
            print(f"  Phone: {merchant.get('phone')}")
            
            print("\n📦 ITEMS:")
            items = result.get('items', [])
            for item in items:
                print(f"  - {item.get('name')}: Rp {int(item.get('price', 0)):,} (qty: {item.get('quantity')})")
            
            print("\n💰 TOTALS:")
            totals = result.get('totals', {})
            print(f"  Subtotal: Rp {int(totals.get('subtotal', 0)):,}")
            print(f"  Tax: Rp {int(totals.get('tax', 0)):,}")
            print(f"  Discount: Rp {int(totals.get('discount', 0)):,}")
            print(f"  Total: Rp {int(totals.get('total', 0)):,}")
            
            print("\n🔍 YOLO DETECTIONS:")
            detections = result.get('yolo_detections', [])
            for det in detections:
                print(f"  - {det.get('class')} (conf: {det.get('confidence')}, "
                      f"ocr_processed: {det.get('ocr_processed')})")
            
            print("\n📝 GROUPED LINES:")
            print(f"  Total: {result.get('grouped_lines_count')}")
            
            print("\n" + "="*80)
            print("✅ TEST PASSED!")
            print("="*80)
            
            # Save full result
            with open('ocr_result.json', 'w') as f:
                json.dump(result, f, indent=2)
            print(f"\n📁 Full result saved to: ocr_result.json")
            
            return True
        else:
            print(f"❌ Error response: {response.text}")
            return False
    
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Run all tests"""
    print("\n" + "="*80)
    print("🧪 CAKU OCR SERVER v4 - TEST SUITE")
    print("="*80)
    print(f"Server URL: {SERVER_URL}")
    print(f"Test Image: {TEST_IMAGE}")
    
    # Test 1: Health check
    if not test_health():
        print("\n❌ Server not responding. Make sure it's running:")
        print(f"   python main.py")
        return
    
    # Test 2: Config
    if not test_config():
        print("\n⚠️  Config endpoint failed")
    
    # Test 3: Predict
    if not test_predict(TEST_IMAGE):
        print("\n⚠️  Prediction endpoint failed")
        return
    
    print("\n" + "="*80)
    print("✅ ALL TESTS COMPLETED!")
    print("="*80)

if __name__ == '__main__':
    main()
