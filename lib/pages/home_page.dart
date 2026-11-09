import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/db_helper.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import 'add_transaction_page.dart';
import 'report_page.dart';
import 'settings_page.dart';
import 'edit_transaction_page.dart';
import 'ocr_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State createState() => _HomePageState();
}

class _HomePageState extends State {
  int _currentIndex = 0;

  Widget _getBody() {
    if (_currentIndex == 0) return const DashboardView();
    if (_currentIndex == 1) return const ReportPage();
    if (_currentIndex == 2) return const OCRPage();
    if (_currentIndex == 3) return const SettingsPage();
    return const DashboardView();
  }

  Widget _buildNavItem(IconData icon, int index) {
    return IconButton(
      icon: Icon(
        icon,
        color: _currentIndex == index ? const Color(0xFFFFC54A) : Colors.grey,
        size: 30,
      ),
      onPressed: () => setState(() => _currentIndex = index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _getBody(),
      floatingActionButton: SizedBox(
        width: 65,
        height: 65,
        child: FloatingActionButton(
          elevation: 8,
          backgroundColor: const Color(0xFF6C63FF),
          shape: const CircleBorder(),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddTransactionPage()),
            );
            setState(() {});
          },
          child: const Icon(Icons.add, size: 32, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: const Color(0xFF0F0F2E),
        elevation: 0,
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_rounded, 0),
            _buildNavItem(Icons.bar_chart_rounded, 1),
            const SizedBox(width: 40),
            _buildNavItem(Icons.receipt_long, 2),
            _buildNavItem(Icons.settings, 3),
          ],
        ),
      ),
    );
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State createState() => _DashboardViewState();
}

class _DashboardViewState extends State {
  double totalSaldo = 0;
  double pemasukan = 0;
  double pengeluaran = 0;
  List<TransactionModel> recentTransactions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedType = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _allCategories = ['all'];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCategories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await DatabaseHelper.instance.getAllCategoryNames();
      if (mounted) {
        setState(() {
          _allCategories = ['all', ...cats];
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      List<TransactionModel> transactions;
      if (_searchQuery.isNotEmpty) {
        transactions = await DatabaseHelper.instance.searchTransactions(_searchQuery);
      } else if (_selectedCategory != 'all' ||
          _selectedType != 'all' ||
          _startDate != null ||
          _endDate != null) {
        transactions = await DatabaseHelper.instance.filterTransactions(
          category: _selectedCategory != 'all' ? _selectedCategory : null,
          type: _selectedType != 'all' ? _selectedType : null,
          startDate: _startDate,
          endDate: _endDate,
        );
      } else {
        transactions = await DatabaseHelper.instance.readAllTransactions();
      }

      double income = 0;
      double expense = 0;
      for (var t in transactions) {
        if (t.type == 'IN') {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }

      if (mounted) {
        setState(() {
          totalSaldo = income - expense;
          pemasukan = income;
          pengeluaran = expense;
          recentTransactions = transactions.take(10).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    try {
      await DatabaseHelper.instance.deleteTransaction(transaction.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi dihapus'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTransactionMenu(TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit'),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditTransactionPage(transaction: transaction),
                  ),
                );
                if (result == true) {
                  _loadData();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Hapus'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(transaction);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(TransactionModel transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: const Text('Apakah Anda yakin ingin menghapus transaksi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTransaction(transaction);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showFilterPanel() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Text('Kategori'),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCategory,
                    items: _allCategories
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat == 'all' ? 'Semua Transaksi' : cat),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 15),
                  const Text('Tipe Transaksi'),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedType,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Semua Transaksi')),
                      DropdownMenuItem(value: 'IN', child: Text('Pemasukan')),
                      DropdownMenuItem(value: 'OUT', child: Text('Pengeluaran')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _selectedType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dari Tanggal'),
                            GestureDetector(
                              onTap: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setModalState(() => _startDate = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_startDate == null
                                    ? 'Pilih'
                                    : DateFormat('yyyy-MM-dd').format(_startDate!)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sampai Tanggal'),
                            GestureDetector(
                              onTap: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setModalState(() => _endDate = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_endDate == null
                                    ? 'Pilih'
                                    : DateFormat('yyyy-MM-dd').format(_endDate!)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedCategory = 'all';
                              _selectedType = 'all';
                              _startDate = null;
                              _endDate = null;
                            });
                            setState(() {
                              _selectedCategory = 'all';
                              _selectedType = 'all';
                              _startDate = null;
                              _endDate = null;
                            });
                            _loadData();
                            Navigator.pop(context);
                          },
                          child: const Text('Reset Filter'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {});
                            _loadData();
                            Navigator.pop(context);
                          },
                          child: const Text('Terapkan Filter'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Stack(
        children: [
          Container(
            height: 300,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A4E), Color(0xFF2D2D99)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "CAKU FINANCE",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Your Personal Finance Tracker",
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Saldo Total",
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _isLoading ? "Rp 0" : currencyFormat.format(totalSaldo),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSummaryItem("Pemasukan", pemasukan,
                              Icons.arrow_downward, currencyFormat),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.white30,
                          ),
                          _buildSummaryItem("Pengeluaran", pengeluaran,
                              Icons.arrow_upward, currencyFormat),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  onChanged: (value) {
                                    setState(() => _searchQuery = value);
                                    _loadData();
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Cari nama...',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              setState(() => _searchQuery = '');
                                              _loadData();
                                            },
                                          )
                                        : null,
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
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 1,
                                child: ElevatedButton.icon(
                                  onPressed: _showFilterPanel,
                                  icon: const Icon(Icons.filter_list, size: 18),
                                  label: const Text('Filter'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : recentTransactions.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.receipt_long,
                                              size: 80, color: Colors.grey[300]),
                                          const SizedBox(height: 16),
                                          Text('Tidak ada hasil',
                                              style: TextStyle(color: Colors.grey[600])),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                        top: 0,
                                        bottom: 0,
                                      ),
                                      itemCount: recentTransactions.length,
                                      itemBuilder: (context, index) {
                                        final transaction = recentTransactions[index];
                                        return GestureDetector(
                                          onLongPress: () =>
                                              _showTransactionMenu(transaction),
                                          child: Card(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            child: ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: transaction.type == 'IN'
                                                    ? AppColors.success
                                                    : AppColors.danger,
                                                child: Icon(
                                                  transaction.type == 'IN'
                                                      ? Icons.arrow_downward
                                                      : Icons.arrow_upward,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              title: Text(
                                                transaction.title,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold),
                                              ),
                                              subtitle: Text(
                                                  '${transaction.category} • ${transaction.date}'),
                                              trailing: Text(
                                                '${transaction.type == 'IN' ? '+' : '-'}${currencyFormat.format(transaction.amount)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: transaction.type == 'IN'
                                                      ? AppColors.success
                                                      : AppColors.danger,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    double amount,
    IconData icon,
    NumberFormat currencyFormat,
  ) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text(currencyFormat.format(amount),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
