import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/db_helper.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  List<Map<String, dynamic>> _chartData = [];
  bool _isLoading = true;
  String _currentType = 'OUT'; // Default tampilkan Pengeluaran

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // Fungsi untuk refresh data saat tab diklik
  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    try {
      // Kita panggil query manual di sini agar fleksibel (IN atau OUT)
      final db = await DatabaseHelper.instance.database;
      final data = await db.rawQuery('''
        SELECT category, SUM(amount) as total 
        FROM transactions 
        WHERE type = ? 
        GROUP BY category
      ''', [_currentType]); // Filter sesuai tipe yang dipilih

      // Filter data valid (tidak null & > 0)
      final validData = data.where((item) {
        final total = item['total'] as num?;
        return total != null && total > 0;
      }).toList();

      if (mounted) {
        setState(() {
          _chartData = validData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading report: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToCSV() async {
    try {
      List<TransactionModel> transactions = await DatabaseHelper.instance.readAllTransactions();
      if (transactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tidak ada data untuk diexport")));
        }
        return;
      }

      List<List<dynamic>> rows = [];
      rows.add(["ID", "Tanggal", "Tipe", "Kategori", "Jumlah", "Keterangan"]);

      for (var t in transactions) {
        rows.add([t.id, t.date, t.type, t.category, t.amount, t.title]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final path = p.join(directory.path, "laporan_caku_${DateTime.now().millisecondsSinceEpoch}.csv");
      
      final file = File(path);
      await file.writeAsString(csvData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Disimpan di: $path"), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal export: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hitung total keseluruhan untuk persentase
    double totalAll = 0;
    for (var item in _chartData) {
      totalAll += (item['total'] as num? ?? 0).toDouble();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan Keuangan"),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. FILTER TOGGLE (Pemasukan / Pengeluaran)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterButton("Pengeluaran", 'OUT', Colors.red),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFilterButton("Pemasukan", 'IN', Colors.green),
                ),
              ],
            ),
          ),

          // 2. KONTEN UTAMA
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _chartData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pie_chart_outline, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text("Belum ada data ${_currentType == 'OUT' ? 'Pengeluaran' : 'Pemasukan'}", style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            // CHART
                            SizedBox(
                              height: 250,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                  sections: _chartData.map((data) {
                                    final double value = (data['total'] as num?)?.toDouble() ?? 0;
                                    final String category = data['category'] ?? '-';
                                    final index = _chartData.indexOf(data);
                                    final color = Colors.primaries[index % Colors.primaries.length];
                                    
                                    return PieChartSectionData(
                                      color: color,
                                      value: value,
                                      title: '${(value / totalAll * 100).toStringAsFixed(0)}%',
                                      radius: 60,
                                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                      badgeWidget: _Badge(category, value, color),
                                      badgePositionPercentageOffset: 1.3,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 50), // Spasi untuk badge

                            // LIST DETAIL
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _chartData.length,
                              separatorBuilder: (_,__) => const Divider(),
                              itemBuilder: (context, index) {
                                final item = _chartData[index];
                                final color = Colors.primaries[index % Colors.primaries.length];
                                final amount = (item['total'] as num? ?? 0);
                                
                                return ListTile(
                                  leading: Container(
                                    width: 16, height: 16,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                                  title: Text(item['category'] ?? '-'),
                                  trailing: Text(
                                    "Rp ${amount.toStringAsFixed(0)}", 
                                    style: const TextStyle(fontWeight: FontWeight.bold)
                                  ),
                                );
                              },
                            ),
                            
                            const SizedBox(height: 30),
                            
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _exportToCSV,
                              icon: const Icon(Icons.download, color: Colors.white),
                              label: const Text("Export CSV", style: TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // Widget Tombol Filter Custom
  Widget _buildFilterButton(String label, String type, Color activeColor) {
    final bool isActive = _currentType == type;
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          setState(() => _currentType = type);
          _loadStats(); // Reload data sesuai tipe baru
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Center(
          child: Text(
            label, 
            style: TextStyle(
              color: isActive ? Colors.white : Colors.black54, 
              fontWeight: FontWeight.bold
            )
          ),
        ),
      ),
    );
  }
}

// Widget Badge (Label di luar chart)
class _Badge extends StatelessWidget {
  final String category;
  final double value;
  final Color color;
  const _Badge(this.category, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          Text("${(value/1000).toStringAsFixed(0)}k", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
