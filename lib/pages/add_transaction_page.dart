import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../utils/constants.dart';
import 'manage_category_page.dart';
import 'ocr_page.dart';

class AddTransactionPage extends StatefulWidget {
  final double? amountFromOCR;
  final String? descriptionFromOCR;

  const AddTransactionPage({
    super.key,
    this.amountFromOCR,
    this.descriptionFromOCR,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  String _type = 'OUT';
  String? _selectedCategoryName;
  List<CategoryModel> _categories = [];
  DateTime _selectedDate = DateTime.now();

  // NumberFormat untuk thousand separator
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'id_ID');

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _loadCategories();

    if (widget.amountFromOCR != null) {
      _amountController.text =
          _currencyFormat.format(widget.amountFromOCR!.toInt());
    }

    if (widget.descriptionFromOCR != null) {
      _titleController.text = widget.descriptionFromOCR!;
    }

    _amountController.addListener(_formatNominal);
  }

  @override
  void dispose() {
    _amountController.removeListener(_formatNominal);
    _amountController.dispose();
    _titleController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _formatNominal() {
    String text = _amountController.text;
    String digitsOnly = text.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.isEmpty) return;

    final formatted = _currencyFormat.format(int.parse(digitsOnly));

    if (text != formatted) {
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await DatabaseHelper.instance.getAllCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openOCRScanner() async {
    try {
      debugPrint('🔍 Opening OCR Scanner from AddTransaction...');
      final result = await Navigator.of(context).push<Map>(
        MaterialPageRoute(
          builder: (context) => const OCRPage(fromAddTransaction: true),
        ),
      );

      debugPrint('📦 OCR Result received: $result');
      if (result != null && result.isNotEmpty && mounted) {
        try {
          final nominal = result['nominal'];
          final keterangan = result['keterangan'];
          debugPrint(
              '✅ Extracted - Nominal: $nominal, Keterangan length: ${keterangan?.length ?? 0}');

          final nominalDouble =
              (nominal is int) ? nominal.toDouble() : (nominal as double);

          setState(() {
            _amountController.text =
                _currencyFormat.format(nominalDouble.toInt());
            _titleController.text = keterangan ?? '';
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Data dari OCR berhasil dimuat!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (parseError) {
          debugPrint('❌ Parse Error: $parseError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Error parsing OCR data: $parseError'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        debugPrint('⚠️ Result is null or empty');
      }
    } catch (e) {
      debugPrint('❌ Exception opening OCR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening OCR: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveTransaction() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      try {
        final transaction = TransactionModel(
          title: _titleController.text,
          amount: double.parse(_amountController.text.replaceAll('.', '')),
          category: _selectedCategoryName ?? 'Lainnya',
          type: _type,
          date: _dateController.text,
        );

        await DatabaseHelper.instance.create(transaction);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Data Tersimpan!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Gagal: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tambah Transaksi"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _openOCRScanner,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Scan Struk (OCR)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = 'IN'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _type == 'IN'
                              ? AppColors.success
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "Pemasukan",
                            style: TextStyle(
                              color:
                                  _type == 'IN' ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = 'OUT'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _type == 'OUT'
                              ? AppColors.danger
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "Pengeluaran",
                            style: TextStyle(
                              color: _type == 'OUT'
                                  ? Colors.white
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ✅ REVISI: Icon Rp sejajar dan field tetap bisa diedit
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textAlignVertical: TextAlignVertical.center, // REVISI 1
                decoration: InputDecoration(
                  labelText: "Nominal",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // REVISI 2: gunakan prefix, bukan prefixIcon
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                    child: Text(
                      'Rp',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  hintText: "Contoh: 5.000",
                ),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 15),

              InputDecorator(
                decoration: InputDecoration(
                  labelText: "Kategori",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.category),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton(
                    isExpanded: true,
                    value: _selectedCategoryName,
                    hint: const Text("Pilih Kategori"),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat.name,
                        child: Row(
                          children: [
                            Icon(cat.icon, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(cat.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCategoryName = val),
                  ),
                ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    if (context.mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageCategoryPage(),
                        ),
                      );
                      _loadCategories();
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 15),
                  label: const Text("Tambah Kategori Baru"),
                ),
              ),
              const SizedBox(height: 1),

              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: () async {
                  FocusScope.of(context).unfocus();
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      _dateController.text =
                          DateFormat('yyyy-MM-dd').format(picked);
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: "Tanggal",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _titleController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: "Keterangan",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.notes),
                  hintText: 'Atau hasil scan struk akan otomatis diisi di sini',
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saveTransaction,
                  child: const Text(
                    "SIMPAN",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
