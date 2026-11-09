import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'pages/home_page.dart';
import 'utils/app_lock.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite untuk Windows/Linux/macOS
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final prefs = await SharedPreferences.getInstance();
  final savedPin = prefs.getString(PinUtils.pinKey);
  final hasPin = savedPin != null && savedPin.isNotEmpty;

  AppLockState.pinEnabled = hasPin;
  await AppConfig.load();

  runApp(MyApp(hasPin: hasPin));
}

class MyApp extends StatefulWidget {
  final bool hasPin;

  const MyApp({super.key, required this.hasPin});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!AppLockState.pinEnabled) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      AppLockState.needsUnlock = true;
    } else if (state == AppLifecycleState.resumed) {
      if (AppLockState.needsUnlock && !AppLockState.lockScreenVisible) {
        AppLockState.needsUnlock = false;
        _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const PinLockScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caku Finance',
      theme: AppThemes.lightTheme,
      navigatorKey: _navigatorKey,
      home: widget.hasPin ? const PinLockScreen() : const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ===== PIN LOCK SCREEN =====
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(seconds: 30);

  String _enteredPin = '';
  String _storedPin = '';
  bool _isLoading = true;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  @override
  void initState() {
    super.initState();
    AppLockState.lockScreenVisible = true;
    AppLockState.needsUnlock = false;
    _loadPin();
  }

  @override
  void dispose() {
    AppLockState.lockScreenVisible = false;
    super.dispose();
  }

  bool get _isLockedOut {
    final until = _lockoutUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  int get _remainingLockoutSeconds {
    final until = _lockoutUntil;
    if (until == null) return 0;
    final seconds = until.difference(DateTime.now()).inSeconds;
    return seconds > 0 ? seconds : 0;
  }

  Future<void> _loadPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(PinUtils.pinKey) ?? '';

    if (!mounted) return;

    // PIN bisa saja dihapus saat aplikasi berjalan.
    if (pin.isEmpty) {
      AppLockState.pinEnabled = false;
      _goToHome(replace: true);
      return;
    }

    setState(() {
      _storedPin = pin;
      _isLoading = false;
    });
  }

  void _goToHome({required bool replace}) {
    final route = MaterialPageRoute(builder: (_) => const HomePage());
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submitPin() async {
    if (_isLockedOut) {
      _showMessage(
        'Terlalu banyak percobaan. Coba lagi dalam '
        '$_remainingLockoutSeconds detik.',
        Colors.orange,
      );
      setState(() => _enteredPin = '');
      return;
    }

    if (PinUtils.verifyPin(_enteredPin, _storedPin)) {
      // Migrasi PIN legacy (plaintext) ke hash.
      if (PinUtils.isLegacyPin(_storedPin)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          PinUtils.pinKey,
          PinUtils.hashPin(_enteredPin),
        );
      }

      if (!mounted) return;
      AppLockState.needsUnlock = false;
      _failedAttempts = 0;
      _lockoutUntil = null;

      // Jika layar PIN dibuka otomatis di atas HomePage, cukup pop.
      // Jika ini layar awal aplikasi, ganti dengan HomePage.
      if (Navigator.of(context).canPop()) {
        _goToHome(replace: false);
      } else {
        _goToHome(replace: true);
      }
    } else {
      _failedAttempts++;

      if (_failedAttempts >= _maxAttempts) {
        _lockoutUntil = DateTime.now().add(_lockoutDuration);
        _failedAttempts = 0;
        _showMessage(
          'PIN salah $_maxAttempts kali. Terkunci '
          '${_lockoutDuration.inSeconds} detik.',
          Colors.red,
        );
      } else {
        final remaining = _maxAttempts - _failedAttempts;
        _showMessage(
          'PIN salah, coba lagi ($remaining percobaan tersisa)',
          Colors.red,
        );
      }

      setState(() => _enteredPin = '');
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _onDigitPressed(String digit) {
    if (_isLockedOut) {
      _showMessage(
        'Terkunci. Coba lagi dalam $_remainingLockoutSeconds detik.',
        Colors.orange,
      );
      return;
    }
    if (_enteredPin.length >= PinUtils.pinLength) return;

    setState(() => _enteredPin += digit);

    if (_enteredPin.length == PinUtils.pinLength) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _submitPin();
      });
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      // Cegah PIN dilewati dengan tombol back saat auto-lock.
      canPop: false,
      child: Scaffold(
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
                  if (_isLockedOut) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Terkunci: $_remainingLockoutSeconds detik',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  // PIN Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      PinUtils.pinLength,
                      (index) {
                        final filled = index < _enteredPin.length;
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
                          final number = index + 1;
                          return _buildPinButton(
                            number.toString(),
                            () => _onDigitPressed(number.toString()),
                          );
                        }),
                        _buildPinButton('⌫', _onBackspacePressed),
                        _buildPinButton('0', () => _onDigitPressed('0')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
