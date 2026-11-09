#!/usr/bin/env python3
"""
CAKU OCR Testing Suite v6.0 - BOTH VERSIONS
- Version A: Tanpa YOLO (EasyOCR only) - Lebih ringan & cepat
- Version B: Dengan YOLO TFLite (Full pipeline) - Lebih akurat untuk deteksi struk
- Standalone version untuk pengujian jarak kamera
- Support: Indonesian receipt OCR
- Output: CSV report + detailed metrics
"""

import os
import cv2
import numpy as np
import pandas as pd
import easyocr
import json
import time
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple, Optional
from PIL import Image, ImageDraw, ImageFont

# ==================== CONFIG ====================

class Config:
    # Paths
    SAMPLES_DIR = "./samples"
    RESULTS_DIR = "./results"
    YOLO_MODEL_PATH = "./models/best_float16.tflite"  # Path ke model YOLO (jika ada)
    
    # Mode selection
    USE_YOLO = False  # Change ke True jika mau pakai YOLO
    
    # OCR Settings
    OCR_LANGUAGES = ['id', 'en']  # Indonesian + English
    OCR_CONFIDENCE_THRESHOLD = 0.3
    
    # YOLO Settings
    YOLO_CONFIDENCE_THRESHOLD = 0.35
    
    # Extraction Settings
    MIN_AMOUNT = 100
    MAX_AMOUNT = 5000000
    
    # Keywords untuk filtering
    SKIP_KEYWORDS = [
        'TOTAL', 'BELANJA', 'TUNAI', 'PPN', 'NPWP',
        'JAKARTA', 'INDOMARET', 'GEDUNG', 'MENARA',
        'BOULEVARD', 'PANTAI', 'INDAH', 'ONGKIR', 'GRATIS',
        'DISKON', 'DESA', 'CIPADUNG', 'TUC', 'VIKE',
        'JL.', 'RT.', 'RH.', 'DPP', 'DITERIMA', 'KASIR', 'TOKO',
        'ALAMAT', 'TELPON', 'NOMOR', 'TOKO', 'TANDA TERIMA'
    ]

# ==================== LOGGER ====================

class Logger:
    @staticmethod
    def info(msg: str):
        print(f"ℹ️  {msg}")
    
    @staticmethod
    def success(msg: str):
        print(f"✅ {msg}")
    
    @staticmethod
    def error(msg: str):
        print(f"❌ {msg}")
    
    @staticmethod
    def warning(msg: str):
        print(f"⚠️  {msg}")
    
    @staticmethod
    def header(msg: str):
        print(f"\n{'='*70}")
        print(f"  {msg}")
        print(f"{'='*70}\n")

# ==================== CURRENCY PARSER ====================

class CurrencyParser:
    @staticmethod
    def parse(text: str) -> float:
        """Parse currency format: 38.000 atau 38,000 -> 38000.0"""
        try:
            text = text.strip()
            # Handle both comma dan dot as separators
            if ',' in text and '.' in text:
                # Assume dot is thousands, comma is decimal
                text = text.replace('.', '').replace(',', '.')
            elif ',' in text:
                # Indonesian format: 38,000 -> 38000
                text = text.replace(',', '')
            return float(text)
        except:
            return 0.0

# ==================== YOLO ENGINE ====================

class YOLOEngine:
    """OPTIONAL: YOLO detection engine using TFLite"""
    
    def __init__(self, model_path: str):
        Logger.info("Initializing YOLO TFLite model...")
        try:
            import tensorflow as tf
            self.interpreter = tf.lite.Interpreter(model_path=model_path)
            self.interpreter.allocate_tensors()
            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()
            self.class_names = ["struk", "info_toko", "items", "total"]
            Logger.success("YOLO TFLite model loaded")
        except ImportError:
            Logger.error("TensorFlow not installed. Install: pip install tensorflow")
            raise
        except Exception as e:
            Logger.error(f"Failed to load YOLO model: {e}")
            raise
    
    def detect(self, image: np.ndarray, conf_threshold: float = 0.35) -> List[Dict]:
        """Run YOLO detection"""
        detections = []
        try:
            input_shape = self.input_details[0]['shape']
            input_height, input_width = input_shape[1], input_shape[2]
            
            resized = cv2.resize(image, (input_width, input_height))
            input_data = np.expand_dims(resized / 255.0, axis=0).astype(np.float32)
            
            self.interpreter.set_tensor(self.input_details[0]['index'], input_data)
            self.interpreter.invoke()
            
            h, w = image.shape[:2]
            
            for output_detail in self.output_details:
                output_data = self.interpreter.get_tensor(output_detail['index'])
                
                if len(output_data.shape) == 3:
                    for detection in output_data[0]:
                        conf = float(detection[4])
                        if conf >= conf_threshold:
                            x, y, w_box, h_box = detection[:4]
                            class_id = int(detection[5]) if len(detection) > 5 else 0
                            
                            x1 = float(x - w_box/2) * w / input_width
                            y1 = float(y - h_box/2) * h / input_height
                            x2 = float(x + w_box/2) * w / input_width
                            y2 = float(y + h_box/2) * h / input_height
                            
                            detections.append({
                                "class": self.class_names[min(class_id, len(self.class_names)-1)],
                                "confidence": round(float(conf), 4),
                                "box": [x1, y1, x2, y2]
                            })
            
            return detections
        except Exception as e:
            Logger.error(f"YOLO detection failed: {e}")
            return []

# ==================== OCR ENGINE ====================

class OCREngine:
    def __init__(self):
        Logger.info("Initializing EasyOCR engine...")
        try:
            self.reader = easyocr.Reader(
                Config.OCR_LANGUAGES,
                gpu=False,  # Set True jika punya GPU CUDA
                model_storage_directory='tmp/easyocr_models'
            )
            Logger.success("EasyOCR initialized")
        except Exception as e:
            Logger.error(f"Failed to initialize OCR: {e}")
            raise
    
    def recognize(self, image_path: str) -> List[Dict]:
        """Run OCR pada gambar, return list of detected text boxes"""
        try:
            image = cv2.imread(image_path)
            if image is None:
                raise ValueError("Gambar tidak bisa dibaca")
            
            results = self.reader.readtext(image, detail=1)
            
            detections = []
            for detection in results:
                bbox_points = detection[0]
                text = detection[1]
                confidence = float(detection[2])
                
                if confidence >= Config.OCR_CONFIDENCE_THRESHOLD:
                    # Convert bbox to list of [x, y] points
                    bbox_converted = [[float(p[0]), float(p[1])] for p in bbox_points]
                    
                    detections.append({
                        'text': text,
                        'confidence': round(confidence, 4),
                        'bbox': bbox_converted,
                        'bbox_center': [
                            sum(p[0] for p in bbox_converted) / len(bbox_converted),
                            sum(p[1] for p in bbox_converted) / len(bbox_converted)
                        ]
                    })
            
            return detections
        except Exception as e:
            Logger.error(f"OCR recognition failed: {e}")
            return []

# ==================== DATA EXTRACTOR ====================

class DataExtractor:
    @staticmethod
    def extract_total(detections: List[Dict]) -> float:
        """Extract total amount dari detections"""
        raw_text = " ".join([d['text'] for d in detections])
        
        # PRIORITY 1: Cari "TOTAL BELANJA"
        total_match = re.search(
            r'(?:TOTAL|BELANJA|JUMLAH)\s*(?:BELANJA)?:?\s*([0-9,.]+)',
            raw_text,
            re.IGNORECASE
        )
        if total_match:
            amount = CurrencyParser.parse(total_match.group(1))
            if Config.MIN_AMOUNT < amount < Config.MAX_AMOUNT:
                Logger.info(f"Found total via TOTAL BELANJA: Rp {amount:,.0f}")
                return amount
        
        # PRIORITY 2: Cari currency amounts dari belakang (usually TOTAL is last)
        lines = raw_text.split('\n')
        for line in reversed(lines):
            # Skip Non-Tunai
            if 'NON' in line.upper() or 'TUNAI' in line.upper():
                continue
            
            matches = re.findall(r'([0-9,.]+)', line)
            if matches:
                for match in reversed(matches):
                    amount = CurrencyParser.parse(match)
                    if Config.MIN_AMOUNT < amount < Config.MAX_AMOUNT:
                        return amount
        
        # PRIORITY 3: Find highest valid amount
        all_amounts = []
        for match in re.findall(r'([0-9,.]+)', raw_text):
            amount = CurrencyParser.parse(match)
            if Config.MIN_AMOUNT < amount < Config.MAX_AMOUNT:
                all_amounts.append(amount)
        
        if all_amounts:
            return max(all_amounts)
        
        return 0.0
    
    @staticmethod
    def extract_items(detections: List[Dict]) -> List[Dict]:
        """Extract item names and prices"""
        items = []
        raw_text = " ".join([d['text'] for d in detections])
        
        # Simple approach: find lines with currency amount
        for detection in detections:
            text = detection['text']
            
            # Skip if contains keywords
            if any(kw in text.upper() for kw in Config.SKIP_KEYWORDS):
                continue
            
            # Look for currency patterns
            matches = re.findall(r'([0-9,.]+)', text)
            if matches:
                for match in matches:
                    amount = CurrencyParser.parse(match)
                    if 500 <= amount <= 500000:
                        item_name = text.replace(match, '').strip()
                        if 3 <= len(item_name) <= 100:
                            items.append({
                                'name': item_name,
                                'price': amount
                            })
        
        return list({item['name'].lower(): item for item in items}.values())

# ==================== TEST RUNNER ====================

class OCRTester:
    def __init__(self, use_yolo: bool = False):
        self.engine = OCREngine()
        self.yolo_engine = None
        self.use_yolo = use_yolo
        self.results = []
        
        # Initialize YOLO if requested
        if use_yolo:
            if os.path.exists(Config.YOLO_MODEL_PATH):
                try:
                    self.yolo_engine = YOLOEngine(Config.YOLO_MODEL_PATH)
                except Exception as e:
                    Logger.warning(f"YOLO initialization failed, will use OCR only: {e}")
                    self.yolo_engine = None
            else:
                Logger.warning(f"YOLO model not found at {Config.YOLO_MODEL_PATH}")
                Logger.warning("Will use OCR only (Version A)")
                self.use_yolo = False
        
        # Create results directory
        Path(Config.RESULTS_DIR).mkdir(exist_ok=True)
    
    def test_image(self, image_path: str, distance_cm: int) -> Dict:
        """Test single image"""
        Logger.header(f"Testing: {Path(image_path).name} @ {distance_cm}cm")
        
        start_time = time.time()
        
        # Load image
        image = cv2.imread(image_path)
        if image is None:
            Logger.error(f"Failed to load image: {image_path}")
            return None
        
        yolo_detections = []
        
        # Step 1: YOLO Detection (optional)
        if self.use_yolo and self.yolo_engine:
            Logger.info("🎯 Running YOLO detection...")
            yolo_detections = self.yolo_engine.detect(image, Config.YOLO_CONFIDENCE_THRESHOLD)
            Logger.success(f"YOLO: {len(yolo_detections)} objects detected")
        
        # Step 2: OCR Recognition
        Logger.info("📝 Running EasyOCR...")
        detections = self.engine.recognize(image_path)
        
        # Step 3: Extract data
        total = DataExtractor.extract_total(detections)
        items = DataExtractor.extract_items(detections)
        
        # Step 4: Calculate metrics
        process_time = time.time() - start_time
        avg_confidence = np.mean([d['confidence'] for d in detections]) if detections else 0
        
        # Determine detection success
        total_detected_success = 1 if total == 38000 else 0  # Adjust 38000 sesuai expected total
        
        result = {
            'filename': Path(image_path).name,
            'distance_cm': distance_cm,
            'yolo_detections': len(yolo_detections),
            'ocr_boxes': len(detections),
            'total_amount': total,
            'total_correct': total_detected_success,
            'items_count': len(items),
            'avg_confidence': round(avg_confidence, 4),
            'process_time_s': round(process_time, 2),
            'status': 'OK' if total > 0 else 'FAIL'
        }
        
        Logger.success(f"OCR Boxes: {result['ocr_boxes']}")
        Logger.success(f"Total: Rp {result['total_amount']:,.0f}")
        Logger.success(f"Items: {result['items_count']}")
        Logger.success(f"Avg Confidence: {result['avg_confidence']:.2%}")
        Logger.success(f"Process Time: {result['process_time_s']}s")
        
        return result
    
    def run_batch(self, image_files: List[Tuple[str, int]]):
        """Run OCR on multiple images"""
        version = "B (dengan YOLO)" if self.use_yolo else "A (tanpa YOLO)"
        Logger.header(f"CAKU OCR TEST v6.0 - Version {version}")
        Logger.info(f"Testing {len(image_files)} samples...")
        Logger.info(f"OCR Confidence Threshold: {Config.OCR_CONFIDENCE_THRESHOLD}")
        if self.use_yolo:
            Logger.info(f"YOLO Confidence Threshold: {Config.YOLO_CONFIDENCE_THRESHOLD}")
        
        for image_path, distance in image_files:
            if os.path.exists(image_path):
                result = self.test_image(image_path, distance)
                if result:
                    self.results.append(result)
            else:
                Logger.error(f"File not found: {image_path}")
    
    def save_report(self):
        """Save results to CSV"""
        if not self.results:
            Logger.warning("No results to save")
            return
        
        df = pd.DataFrame(self.results)
        
        # Create version suffix
        version_suffix = "with_yolo" if self.use_yolo else "no_yolo"
        report_path = os.path.join(
            Config.RESULTS_DIR, 
            f"ocr_report_{version_suffix}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        )
        
        df.to_csv(report_path, index=False)
        Logger.success(f"Report saved: {report_path}")
        
        # Print summary table
        print("\n" + "="*70)
        print("SUMMARY TABLE")
        print("="*70)
        print(df.to_string(index=False))
        print("="*70)
        
        # Print statistics
        print("\n" + "="*70)
        print("STATISTICS")
        print("="*70)
        success_rate = (df['total_correct'].sum() / len(df)) * 100
        avg_confidence = df['avg_confidence'].mean()
        avg_time = df['process_time_s'].mean()
        
        print(f"Success Rate (correct total): {success_rate:.1f}%")
        print(f"Average Confidence: {avg_confidence:.4f} ({avg_confidence*100:.2f}%)")
        print(f"Average Process Time: {avg_time:.2f}s")
        print("="*70)
        
        return report_path

# ==================== MAIN ====================

def main():
    import sys
    
    # Parse command line arguments
    use_yolo = False
    if len(sys.argv) > 1:
        if sys.argv[1].lower() in ['--yolo', '-y', 'yolo']:
            use_yolo = True
        elif sys.argv[1].lower() in ['--no-yolo', '-n', 'no-yolo']:
            use_yolo = False
    
    # Override dari Config jika diperlukan
    use_yolo = use_yolo or Config.USE_YOLO
    
    # Define test samples
    test_samples = [
        ("./samples/sample-9cm.jpg", 9),
        ("./samples/sample-13cm.jpg", 13),
        ("./samples/sample-18cm.jpg", 18),
        ("./samples/sample-22cm.jpg", 22),
        ("./samples/sample-26cm.jpg", 26),
    ]
    
    # Run tests
    tester = OCRTester(use_yolo=use_yolo)
    tester.run_batch(test_samples)
    
    # Save report
    tester.save_report()
    
    Logger.header("✅ TESTING COMPLETE")
    print(f"\nVersion used: {'B (dengan YOLO)' if use_yolo else 'A (tanpa YOLO)'}")
    print(f"Results saved to: {Config.RESULTS_DIR}/")

if __name__ == "__main__":
    main()
