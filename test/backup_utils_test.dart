import 'package:flutter_test/flutter_test.dart';
import 'package:caku_apps/database/db_helper.dart';
import 'package:caku_apps/utils/backup_utils.dart';

void main() {
  group('BackupUtils', () {
    test('memakai nama database yang sama dengan database aktif', () {
      expect(BackupUtils.databaseFileName, DatabaseHelper.databaseName);
      expect(BackupUtils.databaseFileName, 'caku_newdata.db');
    });

    test('nama file backup memakai timestamp agar tidak menimpa backup lama', () {
      final name = BackupUtils.backupFileName(DateTime(2026, 2, 18, 1, 12, 5));

      expect(name, 'caku_backup_20260218_011205.db');
    });
  });
}
