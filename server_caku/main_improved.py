"""
CAKU OCR SERVER v5.7.2 - BUG FIXES
- FIXED: content_type read-only property (FastAPI issue)
- IMPROVED: Smart noise filtering untuk -//TUC-9115/VIKE /
- IMPROVED: Total extraction dengan proper Non-Tunai filtering
- OPTIMIZED: Y-coordinate grouping threshold
"""

import os
os.environ['DISABLE_MODEL_SOURCE_CHECK'] = 'true'

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from easyocr import Reader
import cv2
import numpy as np
import logging
import time
import json
import tensorflow as tf
import re
from typing import List, Dict, Optional
from PIL import Image
from io import BytesIO

# ======================== LOGGING ========================
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ======================== CONFIG ========================
class Config:
    SERVER_HOST = "0.0.0.0"
    SERVER_PORT = 8000
    YOLO_MODEL_PATH = "./models/best_float16.tflite"
    YOLO_CONFIDENCE_THRESHOLD = 0.35
    OCR_CONFIDENCE_THRESHOLD = 0.3
    MAX_IMAGE_SIZE = 4000
    MIN_IMAGE_SIZE = 2000
    USE_PIL_FALLBACK = True

# ======================== MODELS ========================
class MerchantInfo:
    def __init__(self, name="", address="", phone=""):
        self.name = name
        self.address = address
        self.phone = phone
    
    def to_dict(self):
        return {
            "name": self.name,
            "address": self.address,
            "phone": self.phone
        }

class OCRItem:
    def __init__(self, name="", price=0.0, quantity=1):
        self.name = name
        self.price = price
        self.quantity = quantity
    
    def to_dict(self):
        return {
            "name": self.name,
            "price": self.price,
            "quantity": self.quantity
        }

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

# ======================== IMAGE DECODER ========================
class ImageDecoder:
    @staticmethod
    def decode(file_bytes: bytes) -> Optional[np.ndarray]:
        """Decode image with cv2, fallback to PIL"""
        try:
            nparr = np.frombuffer(file_bytes, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if image is not None and image.size > 0:
                logger.info("✅ Image decoded with cv2")
                return image
            
            if Config.USE_PIL_FALLBACK:
                pil_image = Image.open(BytesIO(file_bytes)).convert('RGB')
                image = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
                logger.info("✅ Image decoded with PIL fallback")
                return image
            
            return None
        except Exception as e:
            logger.error(f"❌ Image decode error: {e}")
            if Config.USE_PIL_FALLBACK:
                try:
                    pil_image = Image.open(BytesIO(file_bytes)).convert('RGB')
                    image = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
                    logger.info("✅ Image decoded with PIL (after cv2 fail)")
                    return image
                except:
                    return None
            return None

# ======================== YOLO MODEL ========================
class YOLOv8TFLiteModel:
    def __init__(self, model_path: str):
        self.model_path = model_path
        self.interpreter = None
        self.input_details = None
        self.output_details = None
        self.class_names = ["struk", "info_toko", "items", "total"]
        self.load_model()
    
    def load_model(self):
        try:
            self.interpreter = tf.lite.Interpreter(model_path=self.model_path)
            self.interpreter.allocate_tensors()
            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()
            logger.info(f"✅ YOLOv8 TFLite model loaded: {self.model_path}")
        except Exception as e:
            logger.error(f"❌ Failed to load YOLOv8 TFLite: {e}")
            raise
    
    def predict(self, image: np.ndarray, conf_threshold: float = 0.35) -> List[Dict]:
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
            
            logger.info(f"✅ YOLO detection complete: {len(detections)} objects")
            return detections
        
        except Exception as e:
            logger.error(f"❌ YOLO prediction error: {e}")
            return []

# ======================== IMAGE PROCESSOR ========================
class ImageProcessor:
    @staticmethod
    def preprocess_for_ocr(image: np.ndarray) -> np.ndarray:
        """Preprocess image for better OCR"""
        try:
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
            
            binary = cv2.threshold(enhanced, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]
            
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2, 2))
            dilated = cv2.dilate(binary, kernel, iterations=1)
            
            processed = cv2.cvtColor(dilated, cv2.COLOR_GRAY2BGR)
            
            logger.info("✨ Image preprocessing complete")
            return processed
        
        except Exception as e:
            logger.error(f"❌ Preprocessing error: {e}")
            return image

# ======================== DATA EXTRACTOR v5.7.2 ========================
class DataExtractor:
    @staticmethod
    def _parse_currency(text: str) -> float:
        """Parse currency: '31,500' or '31.500' -> 31500.0"""
        try:
            text = text.strip()
            
            if ',' in text and '.' in text:
                text = text.replace('.', '').replace(',', '.')
            elif ',' in text:
                text = text.replace(',', '')
            
            return float(text)
        except:
            return 0.0
    
    @staticmethod
    def extract_merchant_info(texts: List[str]) -> MerchantInfo:
        """Extract merchant info from texts"""
        info = MerchantInfo()
        
        try:
            for text in texts[:5]:
                if len(text) > 100:
                    continue
                
                text_lower = text.lower()
                
                if not info.name:
                    if not any(char.isdigit() for char in text):
                        info.name = text.strip()
                
                elif re.match(r'^[\d\s\-\+]+$', text):
                    info.phone = text.strip()
                
                elif any(keyword in text_lower for keyword in ['st', 'ave', 'blvd', 'road', 'street', 'jakarta', 'utara', 'selatan']):
                    info.address = text.strip()
            
            logger.info(f"📍 Merchant: {info.name}")
            return info
        
        except Exception as e:
            logger.error(f"❌ Extract merchant error: {e}")
            return info
    
    @staticmethod
    def extract_totals(raw_text: str, ocr_data: List[Dict]) -> OCRTotals:
        """Extract totals - FIXED v5.7.2: Skip Non-Tunai, use TOTAL BELANJA"""
        totals = OCRTotals()
        
        try:
            # PRIORITY 1: Find "TOTAL BELANJA" (actual receipt total)
            total_belanja_match = re.search(
                r'(?:TOTAL|BELANJA|JUMLAH)\s*(?:BELANJA)?\s*:?\s*([0-9,\.]+)',
                raw_text,
                re.IGNORECASE
            )
            
            if total_belanja_match:
                amount = DataExtractor._parse_currency(total_belanja_match.group(1))
                if 100 < amount < 1000000:
                    totals.total = amount
                    totals.subtotal = amount
                    logger.info(f"💰 Total (TOTAL BELANJA): Rp {amount:,.0f}")
                    return totals
            
            # PRIORITY 2: Find currency values NOT preceded by "Non" or "TUNAI"
            lines = raw_text.split('\n')
            
            for line in reversed(lines):
                # Skip Non-Tunai lines
                if 'NON' in line.upper() or 'TUNAI' in line.upper():
                    logger.info(f"⏭️  Skipping line (Non-Tunai): {line[:50]}")
                    continue
                
                # Find last occurrence of formatted currency
                matches = re.findall(r'([0-9,\.]+)', line)
                
                if matches:
                    for match in reversed(matches):
                        amount = DataExtractor._parse_currency(match)
                        
                        if 100 < amount < 1000000:
                            totals.total = amount
                            totals.subtotal = amount
                            logger.info(f"💰 Total (fallback): Rp {amount:,.0f}")
                            return totals
            
            # PRIORITY 3: Find highest valid currency amount
            currency_amounts = []
            for match in re.findall(r'([0-9,\.]+)', raw_text):
                amount = DataExtractor._parse_currency(match)
                if 100 < amount < 1000000:
                    currency_amounts.append(amount)
            
            if currency_amounts:
                totals.total = max(currency_amounts)
                totals.subtotal = totals.total
                logger.info(f"💰 Total (max): Rp {totals.total:,.0f}")
            
            return totals
        
        except Exception as e:
            logger.error(f"❌ Extract totals error: {e}")
            return totals
    
    @staticmethod
    def extract_items(raw_text: str, ocr_data: List[Dict]) -> List[OCRItem]:
        """Extract items with improved noise filtering (v5.7.2)"""
        items = []
        
        # Enhanced skip keywords
        skip_keywords = [
            'TOTAL', 'BELANJA', 'TUNAI', 'PPN', 'NPWP',
            'JAKARTA', 'INDOMARET', 'GEDUNG', 'MENARA',
            'BOULEVARD', 'PANTAI', 'INDAH', 'ONGKIR', 'ORATIS',
            'NON', 'RUPIAH', 'GRATIS', 'DISKON', 'DESA', 'CIPADUNG',
            'TUC', 'VIKE', 'JL.', 'RT.', 'RH.', 'NPWP', 'DPP',  # NEW: Add receipt noise
            'DITERIMA', 'KASIR', 'TOKO', 'ALAMAT', 'TELPON'
        ]
        
        # Receipt metadata regex (to skip completely)
        metadata_pattern = r'^[^A-Z]*[-/].*[-/].*\s*/?$|^TU\d+.*VIKE|^[0-9\s\-/.]+$'
        
        try:
            sorted_boxes = sorted(ocr_data, key=lambda b: b['box_coordinates'][0][1])
            
            groups = []
            current_group = []
            last_y = None
            Y_THRESHOLD = 80
            
            for box in sorted_boxes:
                y = box['box_coordinates'][0][1]
                
                if last_y is None or abs(y - last_y) < Y_THRESHOLD:
                    current_group.append(box)
                    last_y = y
                else:
                    if current_group:
                        groups.append(current_group)
                    current_group = [box]
                    last_y = y
            
            if current_group:
                groups.append(current_group)
            
            logger.info(f"📦 Grouped {len(ocr_data)} boxes into {len(groups)} groups")
            
            processed_names = set()
            
            for group in groups:
                sorted_group = sorted(group, key=lambda b: b['box_coordinates'][0][0])
                
                combined_text = ' '.join([b['text'] for b in sorted_group]).strip()
                avg_confidence = np.mean([b['confidence'] for b in sorted_group])
                
                # FILTER 1: Skip metadata patterns
                if re.match(metadata_pattern, combined_text):
                    logger.info(f"🚫 Skipped metadata: {combined_text[:40]}")
                    continue
                
                # FILTER 2: Skip keywords
                if any(kw in combined_text.upper() for kw in skip_keywords):
                    continue
                
                # FILTER 3: Skip pure numbers or too short
                clean_text = combined_text.replace(',', '').replace('.', '').replace(' ', '').replace('/', '')
                if clean_text.isdigit() or len(clean_text) < 3:
                    continue
                
                # FILTER 4: Skip very low confidence
                if avg_confidence < 0.30:
                    continue
                
                # Extract NAME and PRICE
                name = ''
                price = 0.0
                
                price_matches = re.findall(r'([0-9,\.]+)', combined_text)
                
                if len(price_matches) >= 2:
                    prices = [DataExtractor._parse_currency(p) for p in price_matches]
                    valid_prices = [p for p in prices if 500 <= p <= 1000000]
                    
                    if valid_prices:
                        price = max(valid_prices)
                        name = combined_text
                        for p_str in price_matches:
                            name = name.replace(p_str, '').strip()
                        name = ' '.join(name.split())
                
                elif len(price_matches) == 1:
                    match = re.match(r'^(.+?)\s+([0-9,\.]+)\s*$', combined_text)
                    if match:
                        name = match.group(1).strip()
                        price = DataExtractor._parse_currency(match.group(2))
                
                # Validate and add
                if name and 3 <= len(name) <= 100 and 500 <= price <= 1000000:
                    name_lower = name.lower()
                    
                    if name_lower not in processed_names:
                        items.append(OCRItem(
                            name=name,
                            price=price,
                            quantity=1
                        ))
                        processed_names.add(name_lower)
                        logger.info(f"📦 Item: {name} - Rp {price:,.0f} (conf: {avg_confidence:.2f})")
            
            logger.info(f"✅ {len(items)} items extracted")
            return items
        
        except Exception as e:
            logger.error(f"❌ Extract items error: {e}")
            return items

# ======================== FASTAPI APP ========================
app = FastAPI(
    title="CAKU OCR Server v5.7.2",
    version="5.7.2"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

yolo_model = None
ocr_engine = None

@app.on_event("startup")
async def startup_event():
    global yolo_model, ocr_engine
    
    print("=" * 80)
    print("🚀 CAKU OCR SERVER v5.7.2 - STARTUP")
    print("=" * 80)
    
    try:
        logger.info("Loading YOLOv8 TFLite model...")
        yolo_model = YOLOv8TFLiteModel(Config.YOLO_MODEL_PATH)
        
        logger.info("Loading EasyOCR engine...")
        ocr_engine = Reader(['id', 'en'], gpu=False, model_storage_directory='tmp/easyocr_models')
        
        print("\n✅ ALL MODELS LOADED!")
        print(f"   YOLOv8 TFLite: {Config.YOLO_MODEL_PATH}")
        print(f"   EasyOCR: id, en")
        print(f"   Server: http://0.0.0.0:{Config.SERVER_PORT}")
        print("=" * 80 + "\n")
    
    except Exception as e:
        print(f"\n❌ Error loading models: {e}")
        logger.error(f"Model loading failed: {e}", exc_info=True)
        raise

# ======================== ENDPOINTS ========================
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "version": "5.7.2",
        "yolo_available": yolo_model is not None,
        "ocr_available": ocr_engine is not None
    }

@app.get("/config")
async def get_config():
    return {
        "yolo_model": Config.YOLO_MODEL_PATH,
        "yolo_confidence": Config.YOLO_CONFIDENCE_THRESHOLD,
        "ocr_confidence": Config.OCR_CONFIDENCE_THRESHOLD,
        "max_image_size": Config.MAX_IMAGE_SIZE,
        "min_image_size": Config.MIN_IMAGE_SIZE
    }

@app.post("/predict")
async def predict_receipt(file: UploadFile = File(...)):
    """Process receipt image and extract OCR data (v5.7.2)"""
    start_time = time.time()
    
    try:
        contents = await file.read()
        
        logger.info(f"📸 Processing: {file.filename}")
        image = ImageDecoder.decode(contents)
        
        if image is None or image.size == 0:
            raise HTTPException(
                status_code=400,
                detail="Gagal membaca file gambar"
            )
        
        # ===== YOLO DETECTION =====
        logger.info("🎯 Running YOLO detection...")
        yolo_detections = yolo_model.predict(image, Config.YOLO_CONFIDENCE_THRESHOLD)
        
        # ===== IMAGE PREPROCESSING =====
        logger.info("🖼️  Preprocessing image...")
        h, w = image.shape[:2]
        logger.info(f"Original size: {h}x{w}")
        
        processed_image = ImageProcessor.preprocess_for_ocr(image)
        h, w = processed_image.shape[:2]
        logger.info(f"Resized to: {h}x{w}")
        
        # ===== OCR RECOGNITION =====
        logger.info("📝 Running EasyOCR...")
        ocr_results = ocr_engine.readtext(processed_image, detail=1)
        
        # Parse OCR results
        detailed_results = []
        raw_texts = []
        
        if ocr_results and len(ocr_results) > 0:
            for detection in ocr_results:
                try:
                    bbox_points = detection[0]
                    text = detection[1]
                    confidence = detection[2]
                    
                    if confidence >= Config.OCR_CONFIDENCE_THRESHOLD:
                        bbox_converted = [
                            [float(point[0]), float(point[1])]
                            for point in bbox_points
                        ]
                        
                        detailed_results.append({
                            "text": text,
                            "confidence": round(float(confidence), 4),
                            "box_coordinates": bbox_converted
                        })
                        
                        raw_texts.append(text)
                
                except Exception as e:
                    logger.warning(f"Skipped detection: {e}")
                    continue
        
        # ===== DATA EXTRACTION (v5.7.2) =====
        logger.info("🔍 Extracting structured data...")
        
        raw_text = " ".join(raw_texts)
        
        merchant_info = DataExtractor.extract_merchant_info(raw_texts)
        items = DataExtractor.extract_items(raw_text, detailed_results)
        totals = DataExtractor.extract_totals(raw_text, detailed_results)
        
        # Calculate processing time
        process_time = round(time.time() - start_time, 2)
        
        # Build response
        response = {
            "status": "success",
            "filename": file.filename,
            "process_time_seconds": process_time,
            "yolo_detections": yolo_detections,
            "merchant_info": merchant_info.to_dict(),
            "items": [item.to_dict() for item in items],
            "totals": totals.to_dict(),
            "raw_text": raw_text,
            "detailed_results": detailed_results,
            "average_confidence": round(
                np.mean([r["confidence"] for r in detailed_results])
                if detailed_results else 0, 4
            ),
            "total_ocr_boxes": len(detailed_results),
            "warning": None if detailed_results else "Tidak ada teks terdeteksi"
        }
        
        logger.info(f"✅ Processing complete in {process_time}s")
        logger.info(f"   - YOLO: {len(yolo_detections)} detections")
        logger.info(f"   - OCR: {len(detailed_results)} text boxes")
        logger.info(f"   - Items: {len(items)}")
        
        return JSONResponse(content=response)
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Server error: {str(e)}"
        )

# ======================== MAIN ========================
if __name__ == "__main__":
    import uvicorn
    print("\n🚀 Starting CAKU OCR Server v5.7.2...\n")
    uvicorn.run(
        app,
        host=Config.SERVER_HOST,
        port=Config.SERVER_PORT,
        log_level="info"
    )