import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Penting untuk SchedulerBinding
import '../database/db_helper.dart';
import '../models/category_model.dart';
import '../utils/constants.dart';

class ManageCategoryPage extends StatefulWidget {
  const ManageCategoryPage({super.key});

  @override
  State<ManageCategoryPage> createState() => _ManageCategoryPageState();
}

class _ManageCategoryPageState extends State<ManageCategoryPage> {
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  final List<IconData> _availableIcons = [
    Icons.fastfood, Icons.lunch_dining, Icons.local_cafe, Icons.directions_car,
    Icons.train, Icons.flight, Icons.shopping_bag, Icons.shopping_cart,
    Icons.movie, Icons.sports_esports, Icons.fitness_center, Icons.local_hospital,
    Icons.school, Icons.work, Icons.attach_money, Icons.savings,
    Icons.home, Icons.build, Icons.pets, Icons.card_giftcard,
    Icons.phone_android, Icons.wifi, Icons.bolt, Icons.water_drop
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final data = await DatabaseHelper.instance.getAllCategories();
    if (mounted) {
      setState(() {
        _categories = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    if (category.name == 'Lainnya') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kategori "Lainnya" tidak boleh dihapus'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final affected =
          await DatabaseHelper.instance.countTransactionsByCategory(
        category.name,
      );

      if (affected > 0) {
        await DatabaseHelper.instance.ensureCategoryExists('Lainnya');
        await DatabaseHelper.instance.reassignCategory(
          category.name,
          'Lainnya',
        );
      }

      await DatabaseHelper.instance.deleteCategory(category.id!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            affected > 0
                ? 'Kategori "${category.name}" dihapus. '
                    '$affected transaksi dipindahkan ke "Lainnya".'
                : 'Kategori "${category.name}" dihapus.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _loadCategories();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus kategori: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteCategory(CategoryModel category) async {
    final affected =
        await DatabaseHelper.instance.countTransactionsByCategory(category.name);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: Text(
          affected > 0
              ? 'Kategori "${category.name}" dipakai oleh $affected transaksi. '
                  'Semua transaksi tersebut akan dipindahkan ke kategori '
                  '"Lainnya".'
              : 'Yakin menghapus "${category.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCategory(category);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- SOLUSI ANTI CRASH WINDOWS ---
  void _safePop() {
    // 1. Lepas fokus keyboard
    FocusScope.of(context).unfocus();
    
    // 2. Jadwalkan penutupan halaman SETELAH frame render selesai
    // Ini mencegah bentrok dengan event mouse yang sedang berjalan
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    IconData selectedIcon = _availableIcons[0]; 

    showDialog(
      context: context,
      barrierDismissible: false, // Paksa user pakai tombol kita
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Tambah Kategori"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Nama Kategori",
                        hintText: "Contoh: Tagihan Listrik"
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(alignment: Alignment.centerLeft, child: Text("Pilih Ikon:", style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 10),
                    Container(
                      height: 200, 
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8),
                        itemCount: _availableIcons.length,
                        itemBuilder: (context, index) {
                          final icon = _availableIcons[index];
                          final isSelected = icon == selectedIcon;
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedIcon = icon),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.grey[100],
                                shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: AppColors.secondary, width: 2) : null,
                              ),
                              child: Icon(icon, color: isSelected ? Colors.white : Colors.black54, size: 20),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("Batal")
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                  onPressed: () async {
                    FocusScope.of(context).unfocus(); // Lepas fokus dulu
                    
                    if (nameController.text.isNotEmpty) {
                      final newCat = CategoryModel(name: nameController.text, iconCode: selectedIcon.codePoint);
                      await DatabaseHelper.instance.addCategory(newCat);
                      
                      // TUTUP DIALOG DENGAN AMAN
                      if (context.mounted) {
                        Navigator.pop(context); 
                      }

                      // REFRESH LIST SETELAH FRAME BERIKUTNYA
                      SchedulerBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _loadCategories();
                      });
                    }
                  },
                  child: const Text("Simpan", style: TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kelola Kategori"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _safePop, // GUNAKAN NAVIGASI AMAN
        ),
      ),
      // Mencegah back gesture/tombol fisik
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _safePop();
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Icon(cat.icon, color: AppColors.primary),
                      ),
                      title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteCategory(cat),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
