/// Status kunci aplikasi yang dipakai lintas widget.
class AppLockState {
  AppLockState._();

  /// Apakah PIN aktif. Diperbarui saat PIN dibuat/dihapus.
  static bool pinEnabled = false;

  /// Apakah aplikasi perlu dikunci saat kembali dari background.
  static bool needsUnlock = false;

  /// Apakah layar PIN sedang terlihat (mencegah layar PIN ganda).
  static bool lockScreenVisible = false;
}
