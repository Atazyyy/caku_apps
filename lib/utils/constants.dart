import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ===== OCR SERVER CONFIGURATION =====
class AppConfig {
  static const String defaultServerIp = '172.20.10.11';
  static const int defaultServerPort = 8000;

  static const String _serverIpKey = 'server_ip';
  static const String _serverPortKey = 'server_port';

  static String _serverIp = defaultServerIp;
  static int _serverPort = defaultServerPort;

  static String get serverIp => _serverIp;
  static int get serverPort => _serverPort;
  static String get serverUrl => 'http://$_serverIp:$_serverPort';
  static String get ocrHealthEndpoint => '$serverUrl/health';
  static String get ocrPredictEndpoint => '$serverUrl/predict';
  static const int requestTimeout = 30;
  static const String defaultCurrency = 'Rp';

  /// Membaca konfigurasi server yang tersimpan (dipanggil saat startup).
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedIp = prefs.getString(_serverIpKey);
    final storedPort = prefs.getInt(_serverPortKey);

    if (storedIp != null && storedIp.trim().isNotEmpty) {
      _serverIp = storedIp.trim();
    }
    if (storedPort != null && storedPort > 0 && storedPort <= 65535) {
      _serverPort = storedPort;
    }
  }

  /// Menyimpan konfigurasi server baru dan langsung memakainya.
  static Future<void> save({required String ip, required int port}) async {
    final normalizedIp = ip.trim();
    if (normalizedIp.isEmpty) {
      throw ArgumentError('Alamat IP tidak boleh kosong');
    }
    if (port < 1 || port > 65535) {
      throw ArgumentError('Port harus di antara 1 dan 65535');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverIpKey, normalizedIp);
    await prefs.setInt(_serverPortKey, port);

    _serverIp = normalizedIp;
    _serverPort = port;
  }
}

// ===== OCR RESPONSE MODELS =====
class Item {
  final String name;
  final double price;
  final double? quantity;
  final double? confidence;

  Item({
    required this.name,
    required this.price,
    this.quantity,
    this.confidence,
  });

  factory Item.fromJson(Map json) {
    return Item(
      name: json['name'] ?? 'Unknown',
      price: ((json['price'] is num) ? json['price'] : 0).toDouble(),
      quantity: json['quantity'] != null ? (json['quantity']).toDouble() : null,
      confidence: json['confidence'] != null ? (json['confidence']).toDouble() : null,
    );
  }
}

class MerchantInfo {
  final String? name;
  final String? address;
  final String? phone;
  final double? confidence;

  MerchantInfo({
    this.name,
    this.address,
    this.phone,
    this.confidence,
  });

  factory MerchantInfo.fromJson(Map json) {
    return MerchantInfo(
      name: json['name'],
      address: json['address'],
      phone: json['phone'],
      confidence: json['confidence'] != null ? (json['confidence']).toDouble() : null,
    );
  }
}

class Totals {
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double? confidence;

  Totals({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    this.confidence,
  });

  factory Totals.fromJson(Map json) {
    return Totals(
      subtotal: ((json['subtotal'] is num) ? json['subtotal'] : 0).toDouble(),
      discount: ((json['discount'] is num) ? json['discount'] : 0).toDouble(),
      tax: ((json['tax'] is num) ? json['tax'] : 0).toDouble(),
      total: ((json['total'] is num) ? json['total'] : 0).toDouble(),
      confidence: json['confidence'] != null ? (json['confidence']).toDouble() : null,
    );
  }
}

class OCRResponse {
  final MerchantInfo? merchantInfo;
  final List? items;
  final Totals? totals;
  final String? rawText;
  final String? status;

  OCRResponse({
    this.merchantInfo,
    this.items,
    this.totals,
    this.rawText,
    this.status,
  });

  factory OCRResponse.fromJson(Map json) {
    return OCRResponse(
      merchantInfo: json['merchant_info'] != null
          ? MerchantInfo.fromJson(json['merchant_info'])
          : null,
      items: json['items'] != null
          ? List.from(json['items'].map((x) => Item.fromJson(x)))
          : null,
      totals: json['totals'] != null ? Totals.fromJson(json['totals']) : null,
      rawText: json['raw_text'],
      status: json['status'],
    );
  }
}

// ===== UTILITY FUNCTIONS =====
class AppUtils {
  static String formatRupiah(double amount) {
    final formatter = NumberFormat('#,###');
    return '${AppConfig.defaultCurrency} ${formatter.format(amount.round())}';
  }

  static double parseRupiah(String text) {
    return double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
  }

  static String formatDate(DateTime date) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month]} ${date.year}';
  }

  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return formatDate(dateTime);
    }
  }
}

// ===== WARNA (LIGHT MODE ONLY) =====
class AppColors {
  static const Color primary = Color(0xFF6C63FF);
  static const Color secondary = Color(0xFF7551F2);
  static const Color success = Color(0xFF55C267);
  static const Color danger = Color(0xFFFE655D);
  static const Color warning = Color(0xFFFFC54A);
  static const Color text = Color(0xFF1A1A2E);
  static const Color textLight = Color(0xFF666666);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F5);
  static const Color border = Color(0xFFE0E0E0);
}

// ===== TEMA APLIKASI (LIGHT ONLY) =====
class AppThemes {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: AppColors.text),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: const TextStyle(color: AppColors.textLight),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.text),
      bodyMedium: TextStyle(color: AppColors.text),
      labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );
}

// ===== PIN SECURITY =====
class PinUtils {
  static const String pinKey = 'app_pin'; // SharedPreferences key
  static const int pinLength = 4;
  static const String _salt = 'caku_finance_pin_v1';

  static final RegExp _legacyPinPattern = RegExp(r'^\d{4}$');
  static final RegExp _hashedPinPattern = RegExp(r'^[a-f0-9]{64}$');

  /// Generate SHA-256 hash dengan salt.
  ///
  /// Catatan: PIN hanya 4 digit, sehingga hash ini tetap bisa di-brute force
  /// jika penyerang punya akses ke storage. Pembatasan percobaan di layar PIN
  /// menjadi lapisan pertahanan utama.
  static String hashPin(String pin) {
    return sha256.convert(utf8.encode('$_salt:$pin')).toString();
  }

  /// Apakah nilai tersimpan masih berupa PIN plaintext versi lama?
  static bool isLegacyPin(String storedPin) {
    return _legacyPinPattern.hasMatch(storedPin);
  }

  /// Apakah nilai tersimpan berupa hash SHA-256?
  static bool isHashedPin(String storedPin) {
    return _hashedPinPattern.hasMatch(storedPin);
  }

  /// Validasi PIN yang mendukung format hash baru maupun plaintext legacy.
  static bool verifyPin(String enteredPin, String storedPin) {
    if (storedPin.isEmpty) return false;
    if (isHashedPin(storedPin)) {
      return hashPin(enteredPin) == storedPin;
    }
    return enteredPin == storedPin;
  }

  /// Alias lama agar kode yang sudah ada tetap kompatibel.
  static bool validatePin(String enteredPin, String storedPin) {
    return verifyPin(enteredPin, storedPin);
  }
}
