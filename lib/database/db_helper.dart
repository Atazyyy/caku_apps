import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../models/category_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Fungsi untuk mendapatkan database (lazy loading)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('caku_newdata.db');
    return _database!;
  }

  // Fungsi untuk inisialisasi database (menentukan path untuk Windows/Linux/Mobile)
  Future<Database> _initDB(String filePath) async {
    String path;
    
    if (Platform.isWindows || Platform.isLinux) {
      final Directory documentsDirectory = await getApplicationDocumentsDirectory();
      path = p.join(documentsDirectory.path, filePath);
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, filePath);
    }

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // Fungsi untuk membuat tabel database saat pertama kali install
  Future _createDB(Database db, int version) async {
    // Tabel untuk menyimpan data transaksi
    await db.execute('''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      amount REAL,
      category TEXT,
      type TEXT,
      date TEXT
    )
    ''');

    // Tabel untuk menyimpan kategori custom
    await db.execute('''
    CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      icon_code INTEGER
    )
    ''');

    // Masukkan kategori default saat pertama kali
    await _insertDefaultCategories(db);
  }

  // Fungsi untuk memasukkan kategori default saat instalasi
  Future<void> _insertDefaultCategories(Database db) async {
    final List<CategoryModel> defaults = [
      CategoryModel(name: 'Makanan', iconCode: Icons.fastfood.codePoint),
      CategoryModel(name: 'Transport', iconCode: Icons.directions_bus.codePoint),
      CategoryModel(name: 'Belanja', iconCode: Icons.shopping_cart.codePoint),
      CategoryModel(name: 'Hiburan', iconCode: Icons.movie.codePoint),
      CategoryModel(name: 'Gaji', iconCode: Icons.attach_money.codePoint),
      CategoryModel(name: 'Kesehatan', iconCode: Icons.local_hospital.codePoint),
      CategoryModel(name: 'Lainnya', iconCode: Icons.category.codePoint),
    ];

    for (var cat in defaults) {
      await db.insert('categories', cat.toMap());
    }
  }

  // ===== CRUD TRANSAKSI =====

  // Fungsi untuk membuat/menambah transaksi baru
  Future<int> create(TransactionModel transaction) async {
    final db = await instance.database;
    return await db.insert('transactions', transaction.toMap());
  }

  // Fungsi untuk membaca semua transaksi
  Future<List<TransactionModel>> readAllTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'id DESC');
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  // ✅ TASK 1: Fungsi untuk mencari transaksi berdasarkan query (judul atau kategori)
  Future<List<TransactionModel>> searchTransactions(String query) async {
    if (query.isEmpty) return readAllTransactions();
    
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'title LIKE ? OR category LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'date DESC',
    );
    return result.map((t) => TransactionModel.fromMap(t)).toList();
  }

  // ✅ TASK 2: Fungsi untuk filter transaksi berdasarkan kategori, tipe, dan tanggal
  Future<List<TransactionModel>> filterTransactions({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    String? type,
  }) async {
    final db = await database;
    
    List<String> whereConditions = [];
    List<dynamic> whereArgs = [];
    
    // Filter berdasarkan kategori
    if (category != null && category.isNotEmpty && category != 'all') {
      whereConditions.add('category = ?');
      whereArgs.add(category);
    }
    
    // Filter berdasarkan tipe (IN/OUT)
    if (type != null && type.isNotEmpty && type != 'all') {
      whereConditions.add('type = ?');
      whereArgs.add(type);
    }
    
    // Filter berdasarkan rentang tanggal
    if (startDate != null && endDate != null) {
      whereConditions.add('date BETWEEN ? AND ?');
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate));
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate));
    }
    
    final String? whereClause = whereConditions.isNotEmpty ? whereConditions.join(' AND ') : null;
    final List<dynamic>? finalWhereArgs = whereArgs.isNotEmpty ? whereArgs : null;
    
    final result = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: finalWhereArgs,
      orderBy: 'date DESC',
    );
    
    return result.map((t) => TransactionModel.fromMap(t)).toList();
  }

  // ✅ TASK 3: Fungsi untuk update/mengubah transaksi yang sudah ada
  Future<int> updateTransaction(TransactionModel transaction) async {
    if (transaction.id == null) {
      throw Exception('Transaction ID cannot be null for update');
    }
    
    final db = await database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  // ✅ TASK 3: Fungsi untuk menghapus transaksi berdasarkan ID
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ===== CRUD KATEGORI =====

  // Fungsi untuk mendapatkan semua kategori untuk dropdown
  Future<List<CategoryModel>> getAllCategories() async {
    final db = await instance.database;
    final result = await db.query('categories', orderBy: 'name ASC');
    return result.map((json) => CategoryModel.fromMap(json)).toList();
  }

  // ✅ Fungsi untuk mendapatkan nama-nama kategori unik (untuk filter)
  Future<List<String>> getAllCategoryNames() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM transactions ORDER BY category ASC'
    );
    return result.map((row) => row['category'] as String).toList();
  }

  // Fungsi untuk menambah kategori baru
  Future<int> addCategory(CategoryModel category) async {
    final db = await instance.database;
    return await db.insert('categories', category.toMap());
  }

  // Fungsi untuk menghapus kategori
  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ===== REPORT & STATS =====

  // Fungsi untuk mendapatkan statistik pengeluaran per kategori
  Future<List<Map<String, dynamic>>> getCategoryStats() async {
    final db = await instance.database;
    return await db.rawQuery(
      "SELECT category, SUM(amount) as total FROM transactions WHERE type = 'OUT' GROUP BY category"
    );
  }

  // Fungsi untuk mendapatkan detail saldo (pemasukan, pengeluaran, total)
  Future<Map<String, double>> getBalanceDetails() async {
    final db = await instance.database;
    
    final resultIncome = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type = 'IN'"
    );
    final resultExpense = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type = 'OUT'"
    );
    
    double income = (resultIncome.first['total'] as num?)?.toDouble() ?? 0.0;
    double expense = (resultExpense.first['total'] as num?)?.toDouble() ?? 0.0;
    
    return {
      'income': income,
      'expense': expense,
      'total': income - expense
    };
  }
}
