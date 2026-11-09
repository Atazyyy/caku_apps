import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../utils/constants.dart';
import 'manage_category_page.dart';

class EditTransactionPage extends StatefulWidget {
  final TransactionModel transaction;

  const EditTransactionPage({super.key, required this.transaction});

  @override
  State<EditTransactionPage> createState() => _EditTransactionPageState();
}

class _EditTransactionPageState extends State<EditTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _titleController;
  late TextEditingController _dateController;
  late String _type;
  late String? _selectedCategoryName;
  List<CategoryModel> _categories = [];
  late DateTime _selectedDate;

  /// Kategori untuk dropdown. Jika kategori transaksi sudah tidak ada di
  /// database, tetap ditampilkan agar Dropdown tidak error.
  List<CategoryModel> get _categoryItems {
    final items = List<CategoryModel>.from(_categories);
    final selected = _selectedCategoryName;
    if (selected != null &&
        selected.isNotEmpty &&
        !items.any((category) => category.name == selected)) {
      items.add(
        CategoryModel(
          name: selected,
          iconCode: Icons.category.codePoint,
        ),
      );
    }
    return items;
  }

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.transaction.amount.toStringAsFixed(0),
    );
    _titleController = TextEditingController(
      text: widget.transaction.title,
    );
    _selectedDate = DateTime.parse(widget.transaction.date);
    _dateController = TextEditingController();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _type = widget.transaction.type;
    _selectedCategoryName = widget.transaction.category;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper.instance.getAllCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
      });
    }
  }

  Future<void> _updateTransaction() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      try {
        final updatedTransaction = TransactionModel(
          id: widget.transaction.id,
          title: _titleController.text,
          amount: double.parse(
            _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ),
          category: _selectedCategoryName ?? 'Lainnya',
          type: _type,
          date: _dateController.text,
        );

        await DatabaseHelper.instance.updateTransaction(updatedTransaction);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaksi diperbarui'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Transaksi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
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
                            'Pemasukan',
                            style: TextStyle(
                              color: _type == 'IN'
                                  ? Colors.white
                                  : Colors.black,
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
                            'Pengeluaran',
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
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nominal (Rp)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 15),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.category),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCategoryName,
                    hint: const Text('Pilih Kategori'),
                    items: _categoryItems.map((cat) {
                      return DropdownMenuItem<String>(
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
                    onChanged: (val) {
                      setState(() => _selectedCategoryName = val);
                    },
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
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Tambah Kategori Baru'),
                ),
              ),
              const SizedBox(height: 15),
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
                  labelText: 'Tanggal',
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
                  labelText: 'Keterangan',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.notes),
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
                  onPressed: _updateTransaction,
                  child: const Text(
                    'PERBARUI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
