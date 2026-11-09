import 'package:intl/intl.dart';

/// Hasil konstruksi klausa SQL untuk daftar transaksi.
class TransactionQuery {
  final String? where;
  final List<dynamic>? args;

  const TransactionQuery({this.where, this.args});
}

/// Membangun klausa WHERE untuk filter transaksi.
///
/// Dipisahkan dari [DatabaseHelper] agar mudah diuji tanpa database.
class TransactionFilter {
  final String? search;
  final String? category;
  final String? type;
  final DateTime? startDate;
  final DateTime? endDate;

  const TransactionFilter({
    this.search,
    this.category,
    this.type,
    this.startDate,
    this.endDate,
  });

  TransactionQuery build() {
    final conditions = <String>[];
    final args = <dynamic>[];

    final keyword = search?.trim() ?? '';
    if (keyword.isNotEmpty) {
      conditions.add('(title LIKE ? OR category LIKE ?)');
      args
        ..add('%$keyword%')
        ..add('%$keyword%');
    }

    if (category != null && category!.isNotEmpty && category != 'all') {
      conditions.add('category = ?');
      args.add(category);
    }

    if (type != null && type!.isNotEmpty && type != 'all') {
      conditions.add('type = ?');
      args.add(type);
    }

    final start = startDate;
    final end = endDate;
    if (start != null && end != null) {
      conditions.add('date BETWEEN ? AND ?');
      args
        ..add(_formatDate(start))
        ..add(_formatDate(end));
    } else if (start != null) {
      conditions.add('date >= ?');
      args.add(_formatDate(start));
    } else if (end != null) {
      conditions.add('date <= ?');
      args.add(_formatDate(end));
    }

    if (conditions.isEmpty) {
      return const TransactionQuery();
    }

    return TransactionQuery(
      where: conditions.join(' AND '),
      args: args,
    );
  }

  static String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
