import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../utils/constants.dart';
import '../services/ocr_service.dart';
import 'add_transaction_page.dart';

class OCRPage extends StatefulWidget {
  // ✅ Parameter untuk mendeteksi flow
  final bool fromAddTransaction;

  const OCRPage({
    super.key,
    this.fromAddTransaction = false, // Default false (dari Nav Bar)
  });

  @override
  State<OCRPage> createState() => _OCRPageState();
}

class _OCRPageState extends State<OCRPage> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isServerOnline = false;
  String? _selectedImagePath;
  OCRResponse? _ocrResult;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkServerConnection();
  }

  Future<void> _checkServerConnection() async {
    setState(() => _isLoading = true);
    final isOnline = await OCRService.checkServerConnection();
    if (mounted) {
      setState(() {
        _isServerOnline = isOnline;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImagePath = pickedFile.path;
          _errorMessage = '';
          _ocrResult = null;
        });
        await _uploadAndProcessImage(pickedFile.path);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: ${e.toString()}';
      });
    }
  }

  Future<void> _uploadAndProcessImage(String imagePath) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await OCRService.predictReceipt(imagePath);

      if (mounted) {
        setState(() {
          _ocrResult = result;
          _isLoading = false;
        });
        _showResultDialog(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Processing error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _showResultDialog(OCRResponse data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OCR Results'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data.merchantInfo != null) ...[
                const Text(
                  '📍 Merchant Info',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Name: ${data.merchantInfo!.name ?? 'N/A'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (data.merchantInfo!.confidence != null)
                        Text(
                          'Confidence: ${(data.merchantInfo!.confidence! * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (data.totals != null) ...[
                const Text(
                  '💰 Totals',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            AppUtils.formatRupiah(data.totals!.total),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _useOCRData();
            },
            child: const Text('Use This Data'),
          ),
        ],
      ),
    );
  }

  /// ⭐ FIX LOGIC FLOW DI SINI
  void _useOCRData() {
    if (_ocrResult?.totals != null) {
      final ocrData = {
        'nominal': _ocrResult!.totals!.total,
        'keterangan': _buildKeterangan(),
      };

      debugPrint('🔄 From AddTransaction: ${widget.fromAddTransaction}');

      if (widget.fromAddTransaction) {
        // ✅ FLOW 2 (Dari Add Transaction): Pop balik membawa data
        debugPrint('📤 Popping with data to AddTransaction');
        Navigator.of(context).pop(ocrData);
      } else {
        // ✅ FLOW 1 (Dari Nav Bar): Push biasa (JANGAN pushReplacement)
        debugPrint('📥 Pushing to AddTransaction from nav bar');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AddTransactionPage(
              amountFromOCR: ocrData['nominal'] as double,
              descriptionFromOCR: ocrData['keterangan'] as String,
            ),
          ),
        );
      }
    }
  }

  String _buildKeterangan() {
    List<String> parts = [];

    if (_ocrResult?.merchantInfo?.name != null &&
        _ocrResult!.merchantInfo!.name!.isNotEmpty) {
      parts.add('🏪 ${_ocrResult!.merchantInfo!.name!}');
    }

    if (_ocrResult?.items != null && _ocrResult!.items!.isNotEmpty) {
      List<String> items = _ocrResult!.items!.map((item) {
        return '  • ${item.name} (${AppUtils.formatRupiah(item.price)})';
      }).toList();

      parts.add('📦 Items:');
      parts.addAll(items);
    }

    if (_ocrResult?.totals != null) {
      parts.add('');
      parts.add('💰 Summary:');
      parts.add('  Subtotal: ${AppUtils.formatRupiah(_ocrResult!.totals!.subtotal)}');
      if (_ocrResult!.totals!.discount > 0) {
        parts.add('  Discount: ${AppUtils.formatRupiah(_ocrResult!.totals!.discount)}');
      }
      if (_ocrResult!.totals!.tax > 0) {
        parts.add('  Tax: ${AppUtils.formatRupiah(_ocrResult!.totals!.tax)}');
      }
      parts.add('  Total: ${AppUtils.formatRupiah(_ocrResult!.totals!.total)}');
    }

    return parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📸 OCR Scanner'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isServerOnline
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isServerOnline ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isServerOnline ? Icons.check_circle : Icons.error,
                      color: _isServerOnline ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isServerOnline ? 'Server Ready' : '❌ Server Offline',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isServerOnline ? Colors.green : Colors.red,
                            ),
                          ),
                          Text(
                            '${AppConfig.serverIp}:${AppConfig.serverPort}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _checkServerConnection,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_selectedImagePath != null)
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_selectedImagePath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No image selected',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Processing receipt with AI...',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'YOLOv8 Detection + EasyOCR',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              else ...[
                ElevatedButton.icon(
                  onPressed: _isServerOnline ? () => _pickImage(ImageSource.camera) : null,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed:
                      _isServerOnline ? () => _pickImage(ImageSource.gallery) : null,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Select from Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
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
