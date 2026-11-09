import 'package:flutter_test/flutter_test.dart';
import 'package:caku_apps/database/transaction_filter.dart';

void main() {
  group('TransactionFilter', () {
    test('tanpa filter menghasilkan where kosong', () {
      final query = const TransactionFilter().build();

      expect(query.where, isNull);
      expect(query.args, isNull);
    });

    test('hanya tanggal awal memakai kondisi >=', () {
      final query = TransactionFilter(
        startDate: DateTime(2026, 1, 10),
      ).build();

      expect(query.where, 'date >= ?');
      expect(query.args, ['2026-01-10']);
    });

    test('hanya tanggal akhir memakai kondisi <=', () {
      final query = TransactionFilter(
        endDate: DateTime(2026, 1, 20),
      ).build();

      expect(query.where, 'date <= ?');
      expect(query.args, ['2026-01-20']);
    });

    test('rentang tanggal lengkap memakai BETWEEN', () {
      final query = TransactionFilter(
        startDate: DateTime(2026, 1, 10),
        endDate: DateTime(2026, 1, 20),
      ).build();

      expect(query.where, 'date BETWEEN ? AND ?');
      expect(query.args, ['2026-01-10', '2026-01-20']);
    });

    test('pencarian digabung dengan kategori dan tipe', () {
      final query = const TransactionFilter(
        search: 'kopi',
        category: 'Makanan',
        type: 'OUT',
      ).build();

      expect(query.where, contains('(title LIKE ? OR category LIKE ?)'));
      expect(query.where, contains('category = ?'));
      expect(query.where, contains('type = ?'));
      expect(query.args, ['%kopi%', '%kopi%', 'Makanan', 'OUT']);
    });

    test('nilai all diabaikan', () {
      final query = const TransactionFilter(
        category: 'all',
        type: 'all',
        search: '   ',
      ).build();

      expect(query.where, isNull);
      expect(query.args, isNull);
    });
  });
}
