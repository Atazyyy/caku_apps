# Caku Finance

Aplikasi pencatat keuangan pribadi berbasis Flutter dengan fitur **OCR struk belanja** (YOLOv8 + EasyOCR) untuk mengisi transaksi secara otomatis.

> Proyek Tugas Akhir (Skripsi) — Teknik Informatika.

## ✨ Fitur

- **Dashboard keuangan** — saldo total, pemasukan, dan pengeluaran.
- **Transaksi** — tambah, edit, hapus, cari, serta filter kategori/tipe/rentang tanggal.
- **Kategori custom** — tambah dan hapus kategori beserta ikon.
- **Laporan** — grafik pie pemasukan/pengeluaran per kategori.
- **Export CSV** — unduh transaksi sesuai tab pemasukan/pengeluaran dengan nama file bertimestamp.
- **OCR struk** — foto atau pilih gambar struk, lalu data total & rincian otomatis diisikan ke form transaksi.
- **PIN keamanan** — kunci aplikasi dengan PIN 4 digit (disimpan sebagai hash SHA-256 bersalt, dengan pembatasan 5 percobaan dan auto-lock).
- **Backup database** — salin database SQLite aktif ke folder Documents dengan nama file bertimestamp.
- **Pengaturan server** — atur alamat IP dan port server OCR langsung dari halaman Settings.

## 🧱 Teknologi

| Bagian | Teknologi |
|---|---|
| Aplikasi | Flutter / Dart |
| Database lokal | SQLite (`sqflite`, `sqflite_common_ffi` untuk desktop) |
| Chart | `fl_chart` |
| OCR client | `http` (multipart upload) |
| OCR server | FastAPI, YOLOv8 TFLite, EasyOCR, TensorFlow |

## 📁 Struktur

```
lib/
├── main.dart                     # Entry point + PIN lock
├── database/
│   ├── db_helper.dart            # SQLite singleton, CRUD, filter, index
│   └── transaction_filter.dart   # Builder WHERE untuk filter transaksi
├── models/                       # TransactionModel, CategoryModel
├── pages/
│   ├── home_page.dart            # Bottom nav + dashboard
│   ├── add_transaction_page.dart
│   ├── edit_transaction_page.dart
│   ├── report_page.dart
│   ├── ocr_page.dart
│   ├── manage_category_page.dart
│   └── settings_page.dart
├── services/ocr_service.dart     # HTTP client ke server OCR
└── utils/
    ├── constants.dart            # AppConfig, PinUtils, tema, DTO
    ├── app_lock.dart             # State kunci aplikasi lintas widget
    └── backup_utils.dart         # Penamaan file backup

server_caku/
├── main_improved.py              # Server OCR v5.7.2 (endpoint /predict)
├── main_improved_v6.py           # Server OCR v6 (/predict + /process_receipt)
├── models/best_float16.tflite    # Model YOLOv8 yang dipakai
├── sample/                       # Contoh gambar struk
└── requirements.txt              # Dependency Python
```

## 🚀 Menjalankan Aplikasi

```bash
flutter pub get
flutter run -d windows      # desktop
# atau
flutter run -d android      # perangkat Android
```

## 🖥️ Menjalankan Server OCR

Server disertakan di folder [`server_caku/`](server_caku/) beserta model
`best_float16.tflite` dan contoh gambar struk.

```bash
cd server_caku

# Pertama kali: buat virtual environment & install dependency
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Jalankan server
python main_improved.py
```

Server berjalan di `http://0.0.0.0:8000` dan menyediakan:

- `GET /health`
- `POST /predict` (multipart field `file`)

> Gunakan `main_improved.py` (v5.7.2). Versi `main_improved_v6.py` juga mendukung endpoint `/predict` (alias dari `/process_receipt`), sehingga kompatibel dengan aplikasi ini.

## ⚙️ Konfigurasi Server

Alamat IP dan port server dapat diatur langsung dari aplikasi:

**Settings → Server OCR** — isi IP/host dan port, lalu gunakan tombol **Tes Koneksi** untuk memeriksa koneksi sebelum menyimpan. Nilai disimpan di `SharedPreferences`.

Nilai default (dipakai saat pertama kali) ada di `lib/utils/constants.dart`:

```dart
class AppConfig {
  static const String defaultServerIp = '172.20.10.11';
  static const int defaultServerPort = 8000;
}
```

Pastikan IP tersebut adalah alamat perangkat yang menjalankan server dan berada di jaringan yang sama dengan HP. Android sudah mengizinkan HTTP cleartext untuk koneksi ke server lokal.

## ✅ Status

- `flutter analyze`: 0 issues.
- `flutter test`: 19 test lulus (PIN, filter transaksi, konfigurasi server, backup, widget).
- Target utama: Windows desktop & Android.
- Database aktif: `caku_newdata.db` (folder Documents pada desktop, `getDatabasesPath()` pada mobile).

## 📝 Catatan

Perbaikan yang sudah diterapkan:

- [x] Backup memakai database aktif (`caku_newdata.db`) + nama file bertimestamp.
- [x] Dukungan HTTP cleartext untuk Android.
- [x] Pengaturan IP server dari dalam aplikasi.
- [x] Refresh dashboard otomatis setelah menambah transaksi.
- [x] Filter tanggal fleksibel (hanya tanggal awal/akhir).
- [x] PIN disimpan dalam bentuk hash + pembatasan percobaan.
- [x] Hapus kategori memindahkan transaksi terkait ke "Lainnya" (tidak ada transaksi yatim).
- [x] Parsing nominal hanya menerima digit (aman untuk format ribuan).
