import 'package:intl/intl.dart';

import '../database/db_helper.dart';

/// Helper untuk penamaan file backup database.
class BackupUtils {
  /// Nama database yang benar-benar dipakai aplikasi.
  static const String databaseFileName = DatabaseHelper.databaseName;

  /// Nama file backup dengan timestamp agar backup lama tidak tertimpa.
  ///
  /// Contoh: `caku_backup_20260218_011205.db`
  static String backupFileName(DateTime now) {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(now);
    return 'caku_backup_$stamp.db';
  }
}
