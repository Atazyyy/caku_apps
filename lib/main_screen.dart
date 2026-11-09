import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/report_page.dart';
import 'pages/settings_page.dart';
import 'pages/add_transaction_page.dart';
import 'pages/ocr_page.dart';
import 'utils/constants.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  Key _homeKey = UniqueKey();

  // Pastikan ada 5 widget dalam list untuk 5 icon
  List<Widget> get _pages => [
    HomePage(key: _homeKey),      // 0: Home
    const ReportPage(),           // 1: Report
    const SizedBox(),             // 2: (Space FAB)
    const OCRPage(),              // 3: OCR
    const SettingsPage(),         // 4: Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.secondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddTransactionPage()));
          if (result == true) {
            setState(() {
              _homeKey = UniqueKey(); // REFRESH HOME
              _currentIndex = 0;
            });
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: AppColors.primary,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavIcon(Icons.home_rounded, 0),
              _buildNavIcon(Icons.bar_chart_rounded, 1),
              const SizedBox(width: 40), 
              _buildNavIcon(Icons.receipt_long_rounded, 3), 
              _buildNavIcon(Icons.settings_rounded, 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index) {
    bool isSelected = _currentIndex == index;
    return IconButton(
      icon: Icon(icon, color: isSelected ? AppColors.warning : Colors.white54, size: 28),
      onPressed: () {
        if (index == 2) return;
        setState(() => _currentIndex = index);
      },
    );
  }
}
