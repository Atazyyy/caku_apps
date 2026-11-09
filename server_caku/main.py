from fastapi import FastAPI, File, UploadFile, HTTPException
from easyocr import Reader
import cv2
import numpy as np
import logging
import time
import os

os.environ['DISABLE_MODEL_SOURCE_CHECK'] = 'True'

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="API OCR Caku - Skripsi TA")

print("=" * 70)
print("🚀 Sedang memuat Model AI EasyOCR (Tuned for Receipts)... Mohon tunggu...")
print("=" * 70)
try:
    ocr_engine = Reader(['en'], gpu=False, model_storage_directory='/tmp/easyocr_models')
    print("✅ Model AI SIAP DIGUNAKAN (EasyOCR - Optimized for Thermal Receipts)!")
    print("Server akan tersedia di: http://0.0.0.0:8000")
    print("=" * 70)
except Exception as e:
    print(f"❌ Error saat memuat model: {str(e)}")
    exit(1)

@app.get("/")
def root():
    return {
        "message": "Server OCR Caku Aktif!",
        "status": "Ready",
        "version": "1.0",
        "endpoint": "/predict (POST)"
    }

def preprocess_image(image):
    height, width = image.shape[:2]
    
    if max(height, width) > 4000:
        scale = 4000 / max(height, width)
        new_width = int(width * scale)
        new_height = int(height * scale)
        image = cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_AREA)
        logger.info(f"📋 Gambar di-resize dari ({width}x{height}) ke ({new_width}x{new_height})")
    
    height, width = image.shape[:2]
    if max(height, width) < 2000:
        image = cv2.resize(image, (width * 2, height * 2), interpolation=cv2.INTER_CUBIC)
        logger.info(f"📈 Gambar di-upscale 2x untuk detail lebih jelas")
    
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)
    _, binary = cv2.threshold(enhanced, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2, 2))
    dilated = cv2.dilate(binary, kernel, iterations=1)
    processed = cv2.cvtColor(dilated, cv2.COLOR_GRAY2BGR)
    
    logger.info(f"✨ Preprocessing complete: upscale -> contrast -> binarization -> morphology")
    return processed

@app.post("/predict")
async def predict_receipt(file: UploadFile = File(...)):
    start_time = time.time()
    
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File harus berupa gambar (JPEG, PNG, BMP, etc)")

    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if image is None:
            raise HTTPException(status_code=400, detail="Gagal membaca file gambar. File mungkin corrupt.")

        logger.info(f"📸 Processing image: {file.filename}")
        processed_image = preprocess_image(image)

        logger.info("🔍 Running EasyOCR detection and recognition...")
        results = ocr_engine.readtext(processed_image, detail=1)

        parsed_data = []
        raw_text_list = []
        
        if results is None or len(results) == 0:
            logger.warning("⚠️  Tidak ada teks terdeteksi dalam gambar")
            return {
                "status": "success",
                "filename": file.filename,
                "process_time_seconds": round(time.time() - start_time, 2),
                "total_lines_detected": 0,
                "raw_text": "",
                "detailed_results": [],
                "warning": "Tidak ada teks terdeteksi dalam gambar"
            }
        
        for detection in results:
            try:
                bbox_points = detection[0]
                text = detection[1]
                confidence = detection[2]
                
                if confidence > 0.3:
                    # Convert numpy types to Python native types untuk JSON serialization
                    bbox_converted = [[float(point[0]), float(point[1])] for point in bbox_points]
                    
                    parsed_data.append({
                        "text": text,
                        "confidence": round(float(confidence), 2),
                        "box_coordinates": bbox_converted
                    })
                    raw_text_list.append(text)
                    logger.debug(f"✅ Detected: '{text}' (confidence: {confidence:.2f})")
                else:
                    logger.debug(f"⏭️  Skipped: '{text}' (confidence too low: {confidence:.2f})")
                    
            except (IndexError, TypeError) as e:
                logger.warning(f"⚠️  Skipped invalid detection format: {str(e)}")
                continue

        process_time = round(time.time() - start_time, 2)
        logger.info(f"✅ Selesai diproses dalam {process_time} detik. {len(parsed_data)} lines detected.")

        return {
            "status": "success",
            "filename": file.filename,
            "process_time_seconds": process_time,
            "total_lines_detected": len(parsed_data),
            "raw_text": " ".join(raw_text_list),
            "detailed_results": parsed_data
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    print("\n🔥 Memulai Server...\n")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")