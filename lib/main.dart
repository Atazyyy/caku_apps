import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'pages/home_page.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize sqflite untuk Windows/Linux/macOS
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  final prefs = await SharedPreferences.getInstance();
  final savedPin = prefs.getString('app_pin');
  
  runApp(MyApp(hasPin: savedPin != null));
}

class MyApp extends StatelessWidget {
  final bool hasPin;

  const MyApp({super.key, required this.hasPin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caku Finance',
      theme: AppThemes.lightTheme,
      home: hasPin ? const PinLockScreen() : const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ===== PIN LOCK SCREEN =====
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State {
  String _enteredPin = '';
  String _storedPin = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('app_pin') ?? '';
    
    if (mounted) {
      setState(() {
        _storedPin = pin;
        _isLoading = false;
      });
    }
  }

  void _submitPin() {
    if (_enteredPin == _storedPin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN salah, coba lagi'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _enteredPin = '');
    }
  }

  Widget _buildPinButton(String label, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Caku Finance',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Masukkan PIN Anda',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 30),
                // PIN Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    PinUtils.pinLength,
                    (index) {
                      bool filled = index < _enteredPin.length;
                      return Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: filled
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            filled ? '●' : '',
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
                // PIN Keypad
                SizedBox(
                  width: double.infinity,
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.2,
                    children: [
                      ...List.generate(9, (index) {
                        int number = index + 1;
                        return _buildPinButton(
                          number.toString(),
                          () {
                            if (_enteredPin.length < PinUtils.pinLength) {
                              setState(() {
                                _enteredPin += number.toString();
                              });
                              if (_enteredPin.length == PinUtils.pinLength) {
                                Future.delayed(const Duration(milliseconds: 200), _submitPin);
                              }
                            }
                          },
                        );
                      }),
                      _buildPinButton(
                        '⌫',
                        () {
                          if (_enteredPin.isNotEmpty) {
                            setState(() {
                              _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
                            });
                          }
                        },
                      ),
                      _buildPinButton(
                        '0',
                        () {
                          if (_enteredPin.length < PinUtils.pinLength) {
                            setState(() {
                              _enteredPin += '0';
                            });
                            if (_enteredPin.length == PinUtils.pinLength) {
                              Future.delayed(const Duration(milliseconds: 200), _submitPin);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
