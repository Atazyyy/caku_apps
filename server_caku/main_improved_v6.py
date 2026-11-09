"""
CAKU OCR SERVER v6.0 - ADVANCED PARSING
- IMPROVED: Multi-line item detection
- IMPROVED: Voucher/discount extraction
- IMPROVED: Tax parsing (PB1, PAJAK)
- IMPROVED: Payment method detection
- IMPROVED: Change amount extraction
- FIXED: Complex receipt formats
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
from typing import List, Dict, Optional, Tuple
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
    def __init__(self, name="", price=0.0, quantity=1, subtotal=0.0):
        self.name = name
        self.price = price
        self.quantity = quantity
        self.subtotal = subtotal
    
    def to_dict(self):
        return {
            "name": self.name,
            "price": self.price,
            "quantity": self.quantity,
            "subtotal": self.subtotal
        }

class OCRTotals:
    def __init__(self, subtotal=0.0, discount=0.0, tax=0.0, total=0.0, 
                 payment_method="", change=0.0):
        self.subtotal = subtotal
        self.discount = discount
        self.tax = tax
        self.total = total
        self.payment_method = payment_method
        self.change = change
    
    def to_dict(self):
        return {
            "subtotal": self.subtotal,
            "discount": self.discount,
            "tax": self.tax,
            "total": self.total,
            "payment_method": self.payment_method,
            "change": self.change
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

# ======================== DATA EXTRACTOR v6.0 ========================
class DataExtractor:
    
    @staticmethod
    def _parse_currency(text: str) -> float:
        """Parse currency: '31,500' or '31.500' or 'Rp 31,500' -> 31500.0"""
        try:
            text = text.strip()
            # Remove 'Rp' prefix
            text = re.sub(r'Rp\s*', '', text).strip()
            
            # Handle comma/dot separators
            if ',' in text and '.' in text:
                # Determine which is thousands separator
                last_comma = text.rfind(',')
                last_dot = text.rfind('.')
                if last_comma > last_dot:
                    text = text.replace('.', '').replace(',', '.')
                else:
                    text = text.replace(',', '')
            elif ',' in text:
                # Check if comma is thousands separator (3+ digits after)
                if text.count(',') == 1 and len(text.split(',')[1]) == 3:
                    text = text.replace(',', '')
                else:
                    text = text.replace(',', '.')
            
            return float(text)
        except:
            return 0.0
    
    @staticmethod
    def _is_price_line(text: str) -> bool:
        """Check if line contains price information"""
        patterns = [
            r'@\d+',  # @PRICE
            r'Rp\s*\d',  # Rp AMOUNT
            r'\d+[.,]\d{2,3}(?!\d)',  # Currency format
            r'x\s*\d+',  # quantity x
        ]
        return any(re.search(pattern, text) for pattern in patterns)
    
    @staticmethod
    def extract_merchant_info(texts: List[str]) -> MerchantInfo:
        """Extract merchant info from texts"""
        info = MerchantInfo()
        try:
            for text in texts[:10]:
                if len(text) > 200:
                    continue
                
                text_lower = text.lower()
                
                # Merchant name: first non-empty line with letters only
                if not info.name and not DataExtractor._is_price_line(text):
                    if any(char.isalpha() for char in text):
                        info.name = text.strip()
                
                # Phone: digit pattern matching
                elif not info.phone and re.match(r'^[\d\s\-\+()]{8,}$', text):
                    info.phone = re.sub(r'[^\d+\-()]', '', text)
                
                # Address: contains location keywords
                elif not info.address and any(kw in text_lower for kw in 
                    ['st', 'ave', 'blvd', 'road', 'street', 'jl', 'kec', 'kota', 
                     'jakarta', 'bandung', 'kelurahan', 'cipading', 'cibiru']):
                    info.address = text.strip()
            
            logger.info(f"📍 Merchant: {info.name}")
            return info
        except Exception as e:
            logger.error(f"❌ Extract merchant error: {e}")
            return info
    
    @staticmethod
    def extract_items(raw_text: str, detailed_results: List[Dict]) -> List[OCRItem]:
        """Extract items with improved multi-line handling"""
        items = []
        try:
            # Build text with Y-coordinates for grouping
            text_with_y = []
            for det in detailed_results:
                text = det.get('text', '').strip()
                if text and not DataExtractor._is_noise(text):
                    y_coord = det.get('box_coordinates', [[0,0], [0,0], [0,0], [0,0]])[0][1]
                    text_with_y.append((y_coord, text))
            
            # Sort by Y coordinate
            text_with_y.sort(key=lambda x: x[0])
            
            # Group lines by Y proximity
            groups = []
            current_group = []
            prev_y = None
            
            for y, text in text_with_y:
                if prev_y is None or abs(y - prev_y) < 25:  # 25px threshold
                    current_group.append(text)
                else:
                    if current_group:
                        groups.append(" ".join(current_group))
                    current_group = [text]
                prev_y = y
            
            if current_group:
                groups.append(" ".join(current_group))
            
            # Parse items from groups
            i = 0
            while i < len(groups):
                line = groups[i].strip()
                
                # Skip headers and non-item lines
                if not line or DataExtractor._is_header(line) or DataExtractor._is_total_line(line):
                    i += 1
                    continue
                
                # Pattern: NAME QUANTITY @PRICE TOTAL
                match = re.search(r'(\d+)\s*x?\s*@([\d,\.]+)\s+([\d,\.]+)', line)
                if match:
                    qty = int(match.group(1))
                    price = DataExtractor._parse_currency(match.group(2))
                    total = DataExtractor._parse_currency(match.group(3))
                    
                    # Extract item name (everything before the price info)
                    name = re.sub(r'\d+\s*x?\s*@.*$', '', line).strip()
                    
                    if name and price > 0:
                        items.append(OCRItem(
                            name=name,
                            price=price,
                            quantity=qty,
                            subtotal=total if total > 0 else price * qty
                        ))
                
                # Pattern: NAME @PRICE = TOTAL (single line)
                elif '@' in line:
                    match = re.search(r'@([\d,\.]+)\s*[=x]?\s*([\d,\.]+)?', line)
                    if match:
                        price = DataExtractor._parse_currency(match.group(1))
                        name = re.sub(r'@.*$', '', line).strip()
                        
                        if name and price > 0:
                            items.append(OCRItem(
                                name=name,
                                price=price,
                                quantity=1,
                                subtotal=DataExtractor._parse_currency(match.group(2)) if match.group(2) else price
                            ))
                
                i += 1
            
            logger.info(f"📦 Extracted {len(items)} items")
            return items
        except Exception as e:
            logger.error(f"❌ Extract items error: {e}")
            return []
    
    @staticmethod
    def _is_header(text: str) -> bool:
        """Check if line is a header"""
        headers = ['receipt', 'resi', 'kwitansi', 'nota', 'invoice',
                   'no merchant', 'tanggal', 'kasir', 'item', 'deskripsi']
        return any(h in text.lower() for h in headers)
    
    @staticmethod
    def _is_total_line(text: str) -> bool:
        """Check if line is a total/summary line"""
        total_kws = ['total', 'subtotal', 'sub total', 'tunai', 'non tunai',
                     'kembalian', 'change', 'cash', 'qris', 'debit', 'kredit',
                     'anda hemat', 'diskon', 'pajak', 'tax', 'pb1']
        return any(kw in text.lower() for kw in total_kws)
    
    @staticmethod
    def _is_noise(text: str) -> bool:
        """Check if text is noise/metadata"""
        noise_patterns = [
            r'^[A-Z0-9]{8,}$',  # Long alphanumeric strings
            r'^\d{10,}$',  # Long digit sequences
            r'^[^\w\s\-\(\)]{3,}$',  # Special char sequences
            r'tflx|terima kasih|thank you|kasih|barang|order id|receipt number',
        ]
        return any(re.search(p, text.lower()) for p in noise_patterns)
    
    @staticmethod
    def extract_totals(raw_text: str, detailed_results: List[Dict]) -> OCRTotals:
        """Extract totals with improved detection"""
        totals = OCRTotals()
        
        try:
            # Find lines with total information
            total_lines = [d['text'] for d in detailed_results if DataExtractor._is_total_line(d['text'])]
            text_lower = raw_text.lower()
            
            # Extract SUBTOTAL
            for line in total_lines:
                if 'subtotal' in line.lower() or 'sub total' in line.lower():
                    match = re.search(r'([\d,\.]+)\s*$', line)
                    if match:
                        totals.subtotal = DataExtractor._parse_currency(match.group(1))
            
            # Extract TAX (PB1, PAJAK)
            for line in total_lines:
                if any(kw in line.lower() for kw in ['pb1', 'pajak', 'tax', 'pph']):
                    match = re.search(r'([\d,\.]+)\s*$', line)
                    if match:
                        totals.tax = DataExtractor._parse_currency(match.group(1))
            
            # Extract DISCOUNT (voucher, diskon in parentheses)
            discount_match = re.search(r'\(([\d,\.]+)\)', raw_text)
            if discount_match:
                totals.discount = DataExtractor._parse_currency(discount_match.group(1))
            else:
                # Look for explicit discount lines
                for line in total_lines:
                    if 'diskon' in line.lower() or 'voucher' in line.lower():
                        match = re.search(r'([\d,\.]+)', line)
                        if match:
                            totals.discount = DataExtractor._parse_currency(match.group(1))
            
            # Extract TOTAL (TOTAL BELANJA or just TOTAL)
            for line in total_lines:
                if 'total belanja' in line.lower() or re.match(r'^total\s+', line.lower()):
                    match = re.search(r'([\d,\.]+)\s*$', line)
                    if match:
                        total_val = DataExtractor._parse_currency(match.group(1))
                        if total_val > 0:
                            totals.total = total_val
            
            # If total not found, calculate from items + tax - discount
            if totals.total == 0:
                totals.total = totals.subtotal + totals.tax - totals.discount
            
            # Extract CHANGE (KEMBALIAN)
            for line in total_lines:
                if 'kembalian' in line.lower() or 'change' in line.lower():
                    match = re.search(r'([\d,\.]+)\s*$', line)
                    if match:
                        totals.change = DataExtractor._parse_currency(match.group(1))
            
            # Detect PAYMENT METHOD
            if 'qris' in text_lower:
                totals.payment_method = 'QRIS'
            elif 'debit' in text_lower:
                totals.payment_method = 'Debit Card'
            elif 'kredit' in text_lower:
                totals.payment_method = 'Credit Card'
            elif 'non tunai' in text_lower:
                totals.payment_method = 'Non-Cash'
            elif 'cash' in text_lower or 'tunai' in text_lower:
                totals.payment_method = 'Cash'
            
            logger.info(f"💰 Totals: Rp {totals.total:,.0f} ({totals.payment_method})")
            return totals
        except Exception as e:
            logger.error(f"❌ Extract totals error: {e}")
            return totals

# ======================== FASTAPI APP ========================
app = FastAPI(title="CAKU OCR Server v6.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global models
yolo_model = None
ocr_reader = None

@app.on_event("startup")
async def startup_event():
    global yolo_model, ocr_reader
    logger.info("🚀 Loading models...")
    
    try:
        yolo_model = YOLOv8TFLiteModel(Config.YOLO_MODEL_PATH)
        logger.info("✅ YOLO model loaded")
    except Exception as e:
        logger.warning(f"⚠️ YOLO model not available: {e}")
    
    try:
        ocr_reader = Reader(['id', 'en'], gpu=False)
        logger.info("✅ OCR reader initialized")
    except Exception as e:
        logger.error(f"❌ Failed to load OCR: {e}")
        raise

@app.get("/health")
async def health():
    return {"status": "healthy", "version": "6.0"}

@app.post("/predict")
@app.post("/process_receipt")
async def process_receipt(file: UploadFile = File(...)):
    """Process receipt image with YOLO + OCR + Data extraction"""
    
    start_time = time.time()
    
    try:
        # Read file
        file_bytes = await file.read()
        image = ImageDecoder.decode(file_bytes)
        
        if image is None:
            raise HTTPException(status_code=400, detail="Invalid image file")
        
        logger.info(f"📸 Processing: {file.filename} ({image.shape})")
        
        # YOLO detection
        yolo_detections = []
        if yolo_model:
            yolo_detections = yolo_model.predict(image, Config.YOLO_CONFIDENCE_THRESHOLD)
        
        # Image preprocessing
        processed_image = ImageProcessor.preprocess_for_ocr(image)
        
        # OCR
        logger.info("🔍 Running OCR...")
        ocr_results = ocr_reader.readtext(processed_image)
        
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
        
        # Data extraction
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
        logger.info(f" - YOLO: {len(yolo_detections)} detections")
        logger.info(f" - OCR: {len(detailed_results)} text boxes")
        logger.info(f" - Items: {len(items)}")
        
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
    print("\n🚀 Starting CAKU OCR Server v6.0...\n")
    uvicorn.run(
        app,
        host=Config.SERVER_HOST,
        port=Config.SERVER_PORT,
        log_level="info"
    )
