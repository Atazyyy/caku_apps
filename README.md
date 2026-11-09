# Caku Finance

Aplikasi pencatat keuangan pribadi berbasis Flutter dengan fitur **OCR struk belanja** (YOLOv8 + EasyOCR) untuk mengisi transaksi secara otomatis.

> Proyek Tugas Akhir (Skripsi) — Teknik Informatika.

## ✨ Fitur

- **Dashboard keuangan** — saldo total, pemasukan, dan pengeluaran.
- **Transaksi** — tambah, edit, hapus, cari, serta filter kategori/tipe/rentang tanggal.
- **Kategori custom** — tambah dan hapus kategori beserta ikon.
- **Laporan** — grafik pie pemasukan/pengeluaran per kategori.
- **Export CSV** — unduh seluruh transaksi dalam format CSV.
- **OCR struk** — foto atau pilih gambar struk, lalu data total & rincian otomatis diisikan ke form transaksi.
- **PIN keamanan** — kunci aplikasi dengan PIN 4 digit.
- **Backup database** — salin database SQLite ke folder Documents.

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
├── database/db_helper.dart       # SQLite singleton & CRUD
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
└── utils/constants.dart          # Konfigurasi server, DTO, tema, PIN utils
```

## 🚀 Menjalankan Aplikasi

```bash
flutter pub get
flutter run -d windows      # desktop
# atau
flutter run -d android      # perangkat Android
```

## 🖥️ Menjalankan Server OCR

Server berada di folder terpisah (`../server_caku`).

```bash
cd ../server_caku
.\venv\Scripts\Activate.ps1
python main_improved.py
```

Server berjalan di `http://0.0.0.0:8000` dan menyediakan:

- `GET /health`
- `POST /predict` (multipart field `file`)

> Gunakan `main_improved.py` (v5.7.2). Versi `main_improved_v6.py` memakai endpoint `/process_receipt` sehingga **tidak kompatibel** dengan aplikasi ini.

## ⚙️ Konfigurasi Server

IP dan port server diatur di `lib/utils/constants.dart`:

```dart
class AppConfig {
  static const String serverIp = '172.20.10.11';
  static const int serverPort = 8000;
}
```

Pastikan IP tersebut adalah alamat perangkat yang menjalankan server dan berada di jaringan yang sama dengan HP.

## ✅ Status

- `flutter analyze`: 0 error.
- Target utama: Windows desktop & Android.
- Database aktif: `caku_newdata.db` (folder Documents pada desktop).

## 📝 Catatan

Beberapa perbaikan yang direncanakan:

- [ ] Backup memakai database aktif (`caku_newdata.db`) + nama file bertimestamp.
- [ ] Dukungan HTTP cleartext untuk Android.
- [ ] Pengaturan IP server dari dalam aplikasi.
- [ ] Refresh dashboard otomatis setelah menambah transaksi.
- [ ] Filter tanggal fleksibel (hanya tanggal awal/akhir).
- [ ] PIN disimpan dalam bentuk hash + pembatasan percobaan.
