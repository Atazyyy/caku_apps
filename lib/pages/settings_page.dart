import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ocr_service.dart';
import '../utils/app_lock.dart';
import '../utils/backup_utils.dart';
import '../utils/constants.dart';
import 'manage_category_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _backupData() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final dbFolder = (Platform.isWindows || Platform.isLinux)
          ? documentsDir.path
          : await getDatabasesPath();

      final dbPath = p.join(dbFolder, BackupUtils.databaseFileName);
      final backupPath = p.join(
        documentsDir.path,
        BackupUtils.backupFileName(DateTime.now()),
      );
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Database tidak ditemukan di: $dbPath',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await dbFile.copy(backupPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup berhasil disimpan di: $backupPath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Backup Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup gagal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ===== KONFIGURASI SERVER OCR =====
  Future<void> _editServerConfig() async {
    final formKey = GlobalKey<FormState>();
    final ipController = TextEditingController(text: AppConfig.serverIp);
    final portController =
        TextEditingController(text: AppConfig.serverPort.toString());
    bool isTesting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> saveConfig() async {
              if (!formKey.currentState!.validate()) return;
              await AppConfig.save(
                ip: ipController.text,
                port: int.parse(portController.text.trim()),
              );
              if (!mounted) return;
              setState(() {});
            }

            return AlertDialog(
              title: const Text('Server OCR'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: ipController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Alamat IP / Host',
                        hintText: '172.20.10.11',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Wajib diisi';
                        if (text.contains(' ')) return 'Tidak boleh ada spasi';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '8000',
                      ),
                      validator: (value) {
                        final port = int.tryParse(value?.trim() ?? '');
                        if (port == null || port < 1 || port > 65535) {
                          return 'Port harus 1-65535';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pastikan HP dan komputer server berada di jaringan '
                      'yang sama. Contoh: 172.20.10.11:8000',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isTesting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          await saveConfig();
                          setDialogState(() => isTesting = true);
                          final online =
                              await OCRService.checkServerConnection();
                          if (!mounted) return;
                          setDialogState(() => isTesting = false);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                online
                                    ? 'Server terhubung'
                                    : 'Server tidak dapat dihubungi',
                              ),
                              backgroundColor:
                                  online ? Colors.green : Colors.red,
                            ),
                          );
                        },
                  child: Text(isTesting ? 'Menguji...' : 'Tes Koneksi'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await saveConfig();
                    if (!mounted) return;
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Konfigurasi server disimpan'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    ipController.dispose();
    portController.dispose();
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
                          await prefs.setString(
                            PinUtils.pinKey,
                            PinUtils.hashPin(pin),
                          );
                          AppLockState.pinEnabled = true;

                          if (context.mounted) {
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
                      if (PinUtils.verifyPin(currentPin, storedPin ?? '')) {
                        setDialogState(() {
                          step = 1;
                          currentPin = '';
                        });
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN lama salah'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
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
                        await prefs.setString(
                          PinUtils.pinKey,
                          PinUtils.hashPin(newPin),
                        );
                        AppLockState.pinEnabled = true;
                        if (context.mounted) {
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
                      if (PinUtils.verifyPin(pin, storedPin ?? '')) {
                        await prefs.remove(PinUtils.pinKey);
                        AppLockState.pinEnabled = false;
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ PIN berhasil dihapus'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN salah'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
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
                  color: AppColors.secondary.withValues(alpha: 0.1),
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
          _buildSectionHeader('Koneksi'),
          ListTile(
            leading: const Icon(Icons.dns, color: Colors.teal),
            title: const Text('Server OCR'),
            subtitle: Text('${AppConfig.serverIp}:${AppConfig.serverPort}'),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
            onTap: _editServerConfig,
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
