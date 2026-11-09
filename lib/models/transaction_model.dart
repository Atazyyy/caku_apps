class TransactionModel {
  final int? id;
  final String title; // Keterangan
  final double amount;
  final String category; // Makanan, Transport, dll
  final String type; // 'IN' (Pemasukan) atau 'OUT' (Pengeluaran)
  final String date;

  TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'type': type,
      'date': date,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      category: map['category'],
      type: map['type'],
      date: map['date'],
    );
  }
}
