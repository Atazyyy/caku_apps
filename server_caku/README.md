# Caku OCR Server

Server OCR struk untuk aplikasi **Caku Finance**. Menerima gambar struk, mendeteksi
baris teks dengan **YOLOv8 TFLite**, lalu mengekstrak merchant, item, dan total
menggunakan **EasyOCR**.

## 📋 Kebutuhan

- Python 3.10+ (disarankan 3.10/3.11)
- Windows/Linux/macOS
- Model `models/best_float16.tflite` (sudah disertakan di repo ini)
- Koneksi internet saat pertama kali menjalankan EasyOCR (unduh model OCR otomatis
  ke `tmp/easyocr_models`)

## 🚀 Instalasi

```bash
cd server_caku

# Windows PowerShell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Linux/macOS
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## ▶️ Menjalankan

```bash
python main_improved.py
```

Server berjalan di `http://0.0.0.0:8000`.

Untuk versi v6:

```bash
python main_improved_v6.py
```

## 🔌 Endpoint

| Method | Path | Deskripsi |
|---|---|---|
| `GET` | `/health` | Status server |
| `POST` | `/predict` | Proses gambar struk (multipart field `file`) |
| `POST` | `/process_receipt` | Alias `/predict` pada `main_improved_v6.py` |

Contoh:

```bash
curl -X POST http://localhost:8000/predict -F "file=@sample/sample-13cm.jpeg"
```

## 📁 Struktur

| File | Keterangan |
|---|---|
| `main_improved.py` | Versi utama **v5.7.2** — kompatibel dengan aplikasi (`/predict`) |
| `main_improved_v6.py` | Versi v6 — `/predict` dan `/process_receipt` |
| `main.py`, `main_upgraded.py` | Versi lama (arsip) |
| `models/best_float16.tflite` | Model YOLOv8 yang dipakai |
| `sample/` | Contoh gambar struk untuk pengujian |
| `requirements.txt` | Dependency yang direkomendasikan |
| `ocr_test_v6_both.py`, `test_ocr.py`, dll. | Skrip pengujian manual |

## ⚙️ Menghubungkan ke Aplikasi

1. Jalankan server di komputer yang berada di jaringan yang sama dengan HP.
2. Cari IP komputer tersebut (mis. `ipconfig` → `172.20.10.11`).
3. Di aplikasi Caku Finance: **Settings → Server OCR**, isi IP dan port `8000`,
   lalu tekan **Tes Koneksi**.

## 📝 Catatan

- `venv/`, `tmp/`, `results/`, dan `models/best_float32.tflite` tidak disertakan
  di repo (lihat `.gitignore`).
- Jika `best_float16.tflite` hilang, letakkan model tersebut di `models/` sebelum
  menjalankan server.
- Model float32 (`best_float32.tflite`) berukuran ~99 MB dan tidak diperlukan;
  aplikasi memakai versi float16.
