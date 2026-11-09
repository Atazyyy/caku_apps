import 'package:flutter_test/flutter_test.dart';
import 'package:caku_apps/utils/constants.dart';

void main() {
  group('PinUtils', () {
    test('hashPin tidak menyimpan PIN dalam bentuk plaintext', () {
      final hash = PinUtils.hashPin('1234');

      expect(hash, isNot('1234'));
      expect(hash.length, 64);
    });

    test('hashPin menghasilkan nilai yang sama untuk PIN yang sama', () {
      expect(PinUtils.hashPin('1234'), PinUtils.hashPin('1234'));
    });

    test('verifyPin menerima PIN yang cocok dengan hash', () {
      expect(PinUtils.verifyPin('1234', PinUtils.hashPin('1234')), isTrue);
    });

    test('verifyPin menolak PIN yang salah', () {
      expect(PinUtils.verifyPin('9999', PinUtils.hashPin('1234')), isFalse);
    });

    test('verifyPin tetap mendukung PIN legacy plaintext', () {
      expect(PinUtils.verifyPin('1234', '1234'), isTrue);
      expect(PinUtils.verifyPin('0000', '1234'), isFalse);
    });

    test('isLegacyPin hanya benar untuk PIN 4 digit plaintext', () {
      expect(PinUtils.isLegacyPin('1234'), isTrue);
      expect(PinUtils.isLegacyPin(PinUtils.hashPin('1234')), isFalse);
      expect(PinUtils.isLegacyPin(''), isFalse);
    });
  });
}
