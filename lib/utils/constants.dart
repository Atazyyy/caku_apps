import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ===== OCR SERVER CONFIGURATION =====
class AppConfig {
  static const String serverIp = '172.20.10.11'; //
  static const int serverPort = 8000;
  static String get serverUrl => 'http://$serverIp:$serverPort';
  static String get ocrHealthEndpoint => '$serverUrl/health';
  static String get ocrPredictEndpoint => '$serverUrl/predict';
  static const int requestTimeout = 30;
  static const String defaultCurrency = 'Rp';
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

  // Generate PIN hash (simple version - untuk production gunakan bcrypt)
  static String hashPin(String pin) {
    return pin; // Simplified for demo
  }

  // Validate PIN
  static bool validatePin(String enteredPin, String storedPin) {
    return enteredPin == storedPin;
  }
}
