import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'manage_category_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State createState() => _SettingsPageState();
}

class _SettingsPageState extends State {
  Future<void> _backupData() async {
    try {
      var dbFolder = await getDatabasesPath();
      if (Platform.isWindows || Platform.isLinux) {
        final docDir = await getApplicationDocumentsDirectory();
        dbFolder = docDir.path;
      }

      var dbPath = p.join(dbFolder, 'caku_v8_FINAL.db');
      var outputDir = await getApplicationDocumentsDirectory();
      var backupPath = p.join(outputDir.path, 'caku_backup.db');
      File dbFile = File(dbPath);

      if (await dbFile.exists()) {
        await dbFile.copy(backupPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Backup berhasil disimpan di: $backupPath"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Database tidak ditemukan"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Backup Error: $e");
    }
  }

  // ===== SMART ATUR PIN (Buat atau Ubah otomatis) =====
  Future<void> _manualPinDialog() async {
    // Check apakah sudah ada PIN
    final prefs = await SharedPreferences.getInstance();
    final existingPin = prefs.getString(PinUtils.pinKey);

    if (existingPin == null || existingPin.isEmpty) {
      // Belum ada PIN → Tampilkan dialog BUAT PIN
      _createPinDialog();
    } else {
      // Sudah ada PIN → Tampilkan dialog UBAH PIN
      _changePinDialog();
    }
  }

  // ===== BUAT PIN =====
  Future<void> _createPinDialog() async {
    String pin = '';
    String confirmPin = '';
    int step = 0;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Buat PIN Keamanan'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      step == 0
                          ? 'Masukkan PIN 4 digit'
                          : 'Konfirmasi PIN Anda',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        PinUtils.pinLength,
                        (index) {
                          String currentPin = step == 0 ? pin : confirmPin;
                          bool filled = index < currentPin.length;
                          return Container(
                            width: 45,
                            height: 45,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
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
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 1.3,
                        children: [
                          ...List.generate(9, (index) {
                            int number = index + 1;
                            return _buildPinButton(
                              number.toString(),
                              () {
                                setDialogState(() {
                                  if (step == 0 &&
                                      pin.length < PinUtils.pinLength) {
                                    pin += number.toString();
                                  } else if (step == 1 &&
                                      confirmPin.length <
                                          PinUtils.pinLength) {
                                    confirmPin += number.toString();
                                  }
                                });
                              },
                            );
                          }),
                          _buildPinButton(
                            '⌫',
                            () {
                              setDialogState(() {
                                if (step == 0 && pin.isNotEmpty) {
                                  pin = pin.substring(0, pin.length - 1);
                                } else if (step == 1 &&
                                    confirmPin.isNotEmpty) {
                                  confirmPin = confirmPin.substring(
                                      0, confirmPin.length - 1);
                                }
                              });
                            },
                          ),
                          _buildPinButton(
                            '0',
                            () {
                              setDialogState(() {
                                if (step == 0 &&
                                    pin.length < PinUtils.pinLength) {
                                  pin += '0';
                                } else if (step == 1 &&
                                    confirmPin.length <
                                        PinUtils.pinLength) {
                                  confirmPin += '0';
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (step == 0 && pin.length == PinUtils.pinLength) {
                      setDialogState(() {
                        step = 1;
                        confirmPin = '';
                      });
                    } else if (step == 1) {
                      if (confirmPin.length == PinUtils.pinLength) {
                        if (pin == confirmPin) {
                          final prefs =
                              await SharedPreferences.getInstance();
                          await prefs.setString(PinUtils.pinKey, pin);

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('PIN berhasil dibuat'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN tidak cocok, coba lagi'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setDialogState(() {
                            step = 0;
                            pin = '';
                            confirmPin = '';
                          });
                        }
                      }
                    }
                  },
                  child: Text(step == 0 ? 'Lanjut' : 'Selesai'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===== UBAH PIN =====
  Future<void> _changePinDialog() async {
    String currentPin = '';
    String newPin = '';
    String confirmPin = '';
    int step = 0;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Ubah PIN'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      step == 0
                          ? 'Masukkan PIN Lama'
                          : step == 1
                              ? 'Masukkan PIN Baru'
                              : 'Konfirmasi PIN Baru',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        PinUtils.pinLength,
                        (index) {
                          String currentInput = step == 0
                              ? currentPin
                              : step == 1
                                  ? newPin
                                  : confirmPin;
                          bool filled = index < currentInput.length;
                          return Container(
                            width: 45,
                            height: 45,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
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
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 1.3,
                        children: [
                          ...List.generate(9, (index) {
                            int number = index + 1;
                            return _buildPinButton(
                              number.toString(),
                              () {
                                setDialogState(() {
                                  if (step == 0 &&
                                      currentPin.length < PinUtils.pinLength) {
                                    currentPin += number.toString();
                                  } else if (step == 1 &&
                                      newPin.length < PinUtils.pinLength) {
                                    newPin += number.toString();
                                  } else if (step == 2 &&
                                      confirmPin.length <
                                          PinUtils.pinLength) {
                                    confirmPin += number.toString();
                                  }
                                });
                              },
                            );
                          }),
                          _buildPinButton(
                            '⌫',
                            () {
                              setDialogState(() {
                                if (step == 0 && currentPin.isNotEmpty) {
                                  currentPin = currentPin.substring(
                                      0, currentPin.length - 1);
                                } else if (step == 1 && newPin.isNotEmpty) {
                                  newPin = newPin.substring(0, newPin.length - 1);
                                } else if (step == 2 &&
                                    confirmPin.isNotEmpty) {
                                  confirmPin = confirmPin.substring(
                                      0, confirmPin.length - 1);
                                }
                              });
                            },
                          ),
                          _buildPinButton(
                            '0',
                            () {
                              setDialogState(() {
                                if (step == 0 &&
                                    currentPin.length < PinUtils.pinLength) {
                                  currentPin += '0';
                                } else if (step == 1 &&
                                    newPin.length < PinUtils.pinLength) {
                                  newPin += '0';
                                } else if (step == 2 &&
                                    confirmPin.length <
                                        PinUtils.pinLength) {
                                  confirmPin += '0';
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (step == 0 &&
                        currentPin.length == PinUtils.pinLength) {
                      final prefs = await SharedPreferences.getInstance();
                      final storedPin = prefs.getString(PinUtils.pinKey);
                      if (storedPin == currentPin) {
                        setDialogState(() {
                          step = 1;
                          currentPin = '';
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PIN lama salah'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        setDialogState(() {
                          currentPin = '';
                        });
                      }
                    } else if (step == 1 &&
                        newPin.length == PinUtils.pinLength) {
                      setDialogState(() {
                        step = 2;
                      });
                    } else if (step == 2) {
                      if (newPin == confirmPin) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString(PinUtils.pinKey, newPin);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ PIN berhasil diubah'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PIN tidak cocok'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        setDialogState(() {
                          step = 1;
                          newPin = '';
                          confirmPin = '';
                        });
                      }
                    }
                  },
                  child: Text(step == 2 ? 'Selesai' : 'Lanjut'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===== HAPUS PIN =====
  Future<void> _deletePinDialog() async {
    String pin = '';

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Hapus PIN'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Masukkan PIN untuk verifikasi',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        PinUtils.pinLength,
                        (index) {
                          bool filled = index < pin.length;
                          return Container(
                            width: 45,
                            height: 45,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
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
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 1.3,
                        children: [
                          ...List.generate(9, (index) {
                            int number = index + 1;
                            return _buildPinButton(
                              number.toString(),
                              () {
                                setDialogState(() {
                                  if (pin.length < PinUtils.pinLength) {
                                    pin += number.toString();
                                  }
                                });
                              },
                            );
                          }),
                          _buildPinButton(
                            '⌫',
                            () {
                              setDialogState(() {
                                if (pin.isNotEmpty) {
                                  pin = pin.substring(0, pin.length - 1);
                                }
                              });
                            },
                          ),
                          _buildPinButton(
                            '0',
                            () {
                              setDialogState(() {
                                if (pin.length < PinUtils.pinLength) {
                                  pin += '0';
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (pin.length == PinUtils.pinLength) {
                      final prefs = await SharedPreferences.getInstance();
                      final storedPin = prefs.getString(PinUtils.pinKey);
                      if (storedPin == pin) {
                        await prefs.remove(PinUtils.pinKey);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ PIN berhasil dihapus'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PIN salah'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        setDialogState(() {
                          pin = '';
                        });
                      }
                    }
                  },
                  child: const Text('Hapus PIN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPinButton(String label, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.all(2),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pengaturan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Menu Utama'),
          Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.category, color: AppColors.secondary),
              ),
              title: const Text('Kelola Kategori',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Tambah/hapus kategori'),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageCategoryPage(),
                  ),
                );
              },
            ),
          ),
          _buildSectionHeader('Keamanan'),
          ListTile(
            leading: const Icon(Icons.lock, color: Colors.blue),
            title: const Text('Atur PIN'),
            subtitle: const Text('Buat atau ubah PIN keamanan aplikasi'),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
            onTap: _manualPinDialog,
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Hapus PIN'),
            subtitle: const Text('Nonaktifkan PIN keamanan'),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
            onTap: _deletePinDialog,
          ),
          _buildSectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.backup, color: Colors.blue),
            title: const Text('Backup Data'),
            subtitle: const Text('Simpan database ke folder Documents'),
            onTap: _backupData,
          ),
          const SizedBox(height: 30),
          const Center(
            child: Text(
              "Versi 1.1.0",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.blueGrey,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
