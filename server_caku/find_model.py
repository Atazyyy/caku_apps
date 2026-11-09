#!/usr/bin/env python3
# CAKU OCR - Model Finder
# Search for YOLO model files on your system

import os
import sys
from pathlib import Path

print("=" * 70)
print("🔍 CAKU OCR - Model File Finder")
print("=" * 70)
print()

# ============================================================================
# Search Locations
# ============================================================================
SEARCH_PATHS = [
    # Current project
    './models',
    './model',
    '.',
    
    # Colab locations (if synced)
    './runs/detect/train/weights',
    './runs',
    
    # Common locations
    os.path.expanduser('~/models'),
    os.path.expanduser('~/Downloads'),
    os.path.expanduser('~/Desktop'),
    
    # User documents
    os.path.expanduser('~/Documents'),
    'C:/Users/agnim/Downloads' if os.name == 'nt' else '',
    'C:/Users/agnim/Desktop' if os.name == 'nt' else '',
]

# Model filename variations
MODEL_NAMES = [
    'best_float16.tflite',
    'best.tflite',
    'best_fp16.tflite',
    'model_float16.tflite',
]

print("Searching for YOLO models...")
print("-" * 70)
print()

found_models = []

# ============================================================================
# Search
# ============================================================================
for search_path in SEARCH_PATHS:
    if not search_path or not os.path.exists(search_path):
        continue
    
    try:
        # Search in current directory
        for model_name in MODEL_NAMES:
            full_path = os.path.join(search_path, model_name)
            if os.path.isfile(full_path):
                size_mb = os.path.getsize(full_path) / 1024 / 1024
                found_models.append({
                    'path': full_path,
                    'name': model_name,
                    'size': size_mb
                })
                print(f"✅ FOUND: {full_path}")
                print(f"   Size: {size_mb:.2f} MB")
                print()
    except Exception as e:
        pass

# ============================================================================
# Search subdirectories (deeper search)
# ============================================================================
print("Searching subdirectories (this may take a moment)...")
print()

try:
    for search_path in ['.', 'C:\\Users\\agnim\\Documents' if os.name == 'nt' else os.path.expanduser('~')]:
        if not os.path.exists(search_path):
            continue
        
        for root, dirs, files in os.walk(search_path, topdown=True):
            # Skip hidden dirs and common large dirs
            dirs[:] = [d for d in dirs if not d.startswith('.') and d.lower() not in ['__pycache__', 'node_modules', '.git']]
            
            for file in files:
                if file.endswith('.tflite') and 'best' in file.lower():
                    full_path = os.path.join(root, file)
                    size_mb = os.path.getsize(full_path) / 1024 / 1024
                    found_models.append({
                        'path': full_path,
                        'name': file,
                        'size': size_mb
                    })
                    print(f"✅ FOUND: {full_path}")
                    print(f"   Size: {size_mb:.2f} MB")
                    print()
except KeyboardInterrupt:
    print("\n(Search interrupted)")

# ============================================================================
# Results
# ============================================================================
print()
print("=" * 70)
if found_models:
    print(f"✅ FOUND {len(found_models)} MODEL(S)")
    print("=" * 70)
    print()
    
    for i, model in enumerate(found_models, 1):
        print(f"Model {i}:")
        print(f"  Path: {model['path']}")
        print(f"  Name: {model['name']}")
        print(f"  Size: {model['size']:.2f} MB")
        print()
        
        # Check if size looks right
        if model['size'] < 10:
            print("  ⚠️  WARNING: File seems too small")
        elif model['size'] > 200:
            print("  ⚠️  WARNING: File seems too large")
        else:
            print("  ✅ Size looks good")
        print()
    
    # Suggestion
    print("=" * 70)
    print("NEXT STEP:")
    print("=" * 70)
    print()
    
    best_model = max(found_models, key=lambda x: x['size'])
    print(f"Recommended model: {best_model['path']}")
    print()
    print("Copy it to: ./models/best_float16.tflite")
    print()
    
    if os.name == 'nt':
        print("Command (Windows):")
        print(f'  copy "{best_model["path"]}" .\\models\\best_float16.tflite')
    else:
        print("Command (Linux/Mac):")
        print(f'  cp "{best_model["path"]}" ./models/best_float16.tflite')
    print()

else:
    print("❌ NO MODELS FOUND")
    print("=" * 70)
    print()
    print("WHERE TO GET MODEL:")
    print()
    print("1. Roboflow (Recommended):")
    print("   - Go: https://roboflow.com/your-workspace")
    print("   - Download: TensorFlow Lite export")
    print("   - Extract: best_float16.tflite")
    print()
    print("2. Google Colab:")
    print("   - Check: /content/runs/detect/train/weights/")
    print("   - Download: best_float16.tflite")
    print()
    print("3. Local Training:")
    print("   - Check: ./runs/detect/train/weights/")
    print("   - Look for: best_float16.tflite or best.pt")
    print()

print("=" * 70)
