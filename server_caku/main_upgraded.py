"""
🚀 CAKU OCR SERVER v2 - YOLOv8 TFLite + EasyOCR Integration
Server OCR untuk mengolah receipt/struk dengan YOLOv8 Detection + EasyOCR Recognition

Author: Caku Team | Date: January 2025 | Version: 2.0
"""

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from easyocr import Reader
import cv2
import numpy as np
import logging
import time
import os
import json
import tensorflow as tf
import re
from typing import List, Dict, Optional

# ============================= SETUP =============================

os.environ['DISABLE_MODEL_SOURCE_CHECK'] = 'True'
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ============================= CONFIG =============================

class Config:
    SERVER_HOST = "0.0.0.0"
    SERVER_PORT = 8000
    YOLO_MODEL_PATH = "./models/best_float16.tflite"
    YOLO_CONFIDENCE_THRESHOLD = 0.4
    OCR_CONFIDENCE_THRESHOLD = 0.3
    MAX_IMAGE_SIZE = 4000
    MIN_IMAGE_SIZE = 2000

# ============================= MODELS =============================

class MerchantInfo:
    def __init__(self, name="", address="", phone=""):
        self.name = name
        self.address = address
        self.phone = phone
    
    def to_dict(self):
        return {"name": self.name, "address": self.address, "phone": self.phone}

class OCRItem:
    def __init__(self, name="", price=0.0, quantity=1):
        self.name = name
        self.price = price
        self.quantity = quantity
    
    def to_dict(self):
        return {"name": self.name, "price": self.price, "quantity": self.quantity}

class OCRTotals:
    def __init__(self, subtotal=0.0, discount=0.0, tax=0.0, total=0.0):
        self.subtotal = subtotal
        self.discount = discount
        self.tax = tax
        self.total = total
    
    def to_dict(self):
        return {
            "subtotal": self.subtotal,
            "discount": self.discount,
            "tax": self.tax,
            "total": self.total
        }

# ============================= YOLO MODEL =============================

class YOLOv8TFLiteModel:
    def __init__(self, model_path: str):
        self.model_path = model_path
        self.interpreter = None
        self.input_details = None
        self.output_details = None
        self.class_names = ['struk', 'info_toko', 'items', 'total']
        self._load_model()
    
    def _load_model(self):
        try:
            self.interpreter = tf.lite.Interpreter(model_path=self.model_path)
            self.interpreter.allocate_tensors()
            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()
            logger.info(f"✅ YOLOv8 TFLite model loaded: {self.model_path}")
        except Exception as e:
            logger.error(f"❌ Failed to load YOLOv8 TFLite model: {str(e)}")
            raise
    
    def predict(self, image: np.ndarray, conf_threshold: float = 0.4) -> List[Dict]:
        try:
            input_shape = self.input_details[0]['shape']
            input_height, input_width = input_shape[1], input_shape[2]
            
            resized = cv2.resize(image, (input_width, input_height))
            input_data = np.expand_dims(resized / 255.0, axis=0).astype(np.float32)
            
            self.interpreter.set_tensor(self.input_details[0]['index'], input_data)
            self.interpreter.invoke()
            
            detections = []
            h, w = image.shape[:2]
            
            for output_detail in self.output_details:
                output_data = self.interpreter.get_tensor(output_detail['index'])
                
                if len(output_data.shape) == 3:
                    for detection in output_data[0]:
                        conf = float(detection[4])
                        if conf > conf_threshold:
                            x, y, w_box, h_box = detection[0:4]
                            class_id = int(detection[5]) if len(detection) > 5 else 0
                            
                            x1, y1 = float(x - w_box/2), float(y - h_box/2)
                            x2, y2 = float(x + w_box/2), float(y + h_box/2)
                            
                            x1 = (x1 / input_width) * w
                            x2 = (x2 / input_width) * w
                            y1 = (y1 / input_height) * h
                            y2 = (y2 / input_height) * h
                            
                            detections.append({
                                'class': self.class_names[min(class_id, len(self.class_names)-1)],
                                'confidence': conf,
                                'box': [x1, y1, x2, y2]
                            })
            
            logger.info(f"✅ YOLOv8 detection complete: {len(detections)} objects found")
            return detections
        except Exception as e:
            logger.error(f"❌ YOLOv8 prediction error: {str(e)}")
            return []

# ============================= IMAGE PROCESSING =============================

class ImageProcessor:
    @staticmethod
    def preprocess_for_ocr(image: np.ndarray) -> np.ndarray:
        height, width = image.shape[:2]
        
        if max(height, width) > Config.MAX_IMAGE_SIZE:
            scale = Config.MAX_IMAGE_SIZE / max(height, width)
            new_width = int(width * scale)
            new_height = int(height * scale)
            image = cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_AREA)
        
        height, width = image.shape[:2]
        if max(height, width) < Config.MIN_IMAGE_SIZE:
            image = cv2.resize(image, (width * 2, height * 2), interpolation=cv2.INTER_CUBIC)
        
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
        enhanced = clahe.apply(gray)
        _, binary = cv2.threshold(enhanced, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2, 2))
        dilated = cv2.dilate(binary, kernel, iterations=1)
        processed = cv2.cvtColor(dilated, cv2.COLOR_GRAY2BGR)
        
        logger.info("✨ Image preprocessing complete")
        return processed

# ============================= DATA EXTRACTION =============================

class DataExtractor:
    @staticmethod
    def extract_merchant_info(texts: List[str]) -> MerchantInfo:
        info = MerchantInfo()
        for text in texts[:5]:
            if len(text) < 100:
                if not info.name and not any(char.isdigit() for char in text):
                    info.name = text.strip()
                elif re.match(r'^[\d\s\-\(\)]+$', text):
                    info.phone = text.strip()
                elif any(keyword in text.lower() for keyword in ['st', 'ave', 'blvd', 'road', 'street']):
                    info.address = text.strip()
        return info
    
    @staticmethod
    def extract_items(texts: List[str]) -> List[OCRItem]:
        items = []
        price_pattern = r'\$?(\d+\.?\d*)'
        for text in texts:
            prices = re.findall(price_pattern, text)
            if prices:
                try:
                    price = float(prices[-1])
                    item_name = re.sub(price_pattern, '', text).strip()
                    if item_name and len(item_name) > 2:
                        items.append(OCRItem(name=item_name, price=price, quantity=1))
                except ValueError:
                    continue
        return items
    
    @staticmethod
    def extract_totals(texts: List[str]) -> OCRTotals:
        totals = OCRTotals()
        price_pattern = r'\$?(\d+\.?\d*)'
        for text in texts:
            text_lower = text.lower()
            if 'total' in text_lower:
                prices = re.findall(price_pattern, text)
                if prices:
                    try:
                        totals.total = float(prices[-1])
                    except ValueError:
                        pass
            elif 'subtotal' in text_lower or 'sub' in text_lower:
                prices = re.findall(price_pattern, text)
                if prices:
                    try:
                        totals.subtotal = float(prices[-1])
                    except ValueError:
                        pass
            elif 'discount' in text_lower or 'save' in text_lower:
                prices = re.findall(price_pattern, text)
                if prices:
                    try:
                        totals.discount = float(prices[-1])
                    except ValueError:
                        pass
        
        if totals.subtotal == 0 and totals.total > 0:
            totals.subtotal = totals.total + totals.discount
        
        return totals

# ============================= SERVER INIT =============================

app = FastAPI(title="Caku OCR Server v2", version="2.0")

yolo_model = None
ocr_engine = None

@app.on_event("startup")
async def startup_event():
    global yolo_model, ocr_engine
    
    print("\n" + "="*80)
    print("🚀 Sedang memuat Model AI (YOLOv8 TFLite + EasyOCR)... Mohon tunggu...")
    print("="*80 + "\n")
    
    try:
        logger.info("📦 Loading YOLOv8 TFLite model...")
        yolo_model = YOLOv8TFLiteModel(Config.YOLO_MODEL_PATH)
        
        logger.info("📦 Loading EasyOCR engine...")
        ocr_engine = Reader(['id', 'en'], gpu=False, model_storage_directory='/tmp/easyocr_models')
        
        print("\n" + "="*80)
        print("✅ Model AI SIAP DIGUNAKAN!")
        print(f"   - YOLOv8 TFLite: {Config.YOLO_MODEL_PATH}")
        print(f"   - EasyOCR: id/en")
        print(f"Server akan tersedia di: http://{Config.SERVER_HOST}:{Config.SERVER_PORT}")
        print("="*80 + "\n")
        
    except Exception as e:
        print(f"\n❌ Error saat memuat model: {str(e)}\n")
        logger.error(f"Model loading failed: {str(e)}", exc_info=True)
        exit(1)

# ============================= ENDPOINTS =============================

@app.get("/")
async def root():
    return {
        "message": "Server OCR Caku v2 Aktif!",
        "status": "Ready",
        "version": "2.0",
        "endpoint": "/predict (POST)"
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "yolo_model": "loaded" if yolo_model else "not_loaded",
        "ocr_engine": "loaded" if ocr_engine else "not_loaded"
    }

@app.post("/predict")
async def predict_receipt(file: UploadFile = File(...)):
    start_time = time.time()
    
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File harus berupa gambar")
    
    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            raise HTTPException(status_code=400, detail="Gagal membaca file gambar")
        
        logger.info(f"📸 Processing receipt: {file.filename}")
        
        # YOLOv8 Detection
        logger.info("🔍 Running YOLOv8 detection...")
        detections = yolo_model.predict(image, Config.YOLO_CONFIDENCE_THRESHOLD)
        
        # Image Preprocessing
        processed_image = ImageProcessor.preprocess_for_ocr(image)
        
        # EasyOCR
        logger.info("📝 Running EasyOCR recognition...")
        ocr_results = ocr_engine.readtext(processed_image, detail=1)
        
        # Parse Results
        parsed_data = []
        raw_text_list = []
        
        if ocr_results and len(ocr_results) > 0:
            for detection in ocr_results:
                try:
                    bbox_points = detection[0]
                    text = detection[1]
                    confidence = detection[2]
                    
                    if confidence > Config.OCR_CONFIDENCE_THRESHOLD:
                        bbox_converted = [[float(point[0]), float(point[1])] for point in bbox_points]
                        parsed_data.append({
                            "text": text,
                            "confidence": round(float(confidence), 2),
                            "box_coordinates": bbox_converted
                        })
                        raw_text_list.append(text)
                        logger.debug(f"✅ Detected: '{text}' conf={confidence:.2f}")
                except Exception as e:
                    logger.warning(f"⚠️ Skipped detection: {str(e)}")
                    continue
        
        # Extract Data
        texts = [result['text'] for result in parsed_data]
        merchant_info = DataExtractor.extract_merchant_info(texts)
        items = DataExtractor.extract_items(texts)
        totals = DataExtractor.extract_totals(texts)
        
        process_time = round(time.time() - start_time, 2)
        
        response = {
            "status": "success",
            "filename": file.filename,
            "process_time_seconds": process_time,
            "merchant_info": merchant_info.to_dict(),
            "items": [item.to_dict() for item in items],
            "totals": totals.to_dict(),
            "raw_text": " ".join(raw_text_list),
            "detailed_results": parsed_data,
            "average_confidence": round(np.mean([r['confidence'] for r in parsed_data]) if parsed_data else 0, 2),
            "warning": None if parsed_data else "Tidak ada teks terdeteksi"
        }
        
        logger.info(f"✅ Processing complete in {process_time}s")
        return JSONResponse(content=response)
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")

# ============================= MAIN =============================

if __name__ == "__main__":
    import uvicorn
    print("\n🔥 Memulai Server OCR Caku v2...\n")
    uvicorn.run(app, host=Config.SERVER_HOST, port=Config.SERVER_PORT, log_level="info")
