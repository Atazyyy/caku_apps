import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:caku_apps/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppConfig', () {
    test('memakai nilai default saat belum pernah disimpan', () async {
      SharedPreferences.setMockInitialValues({});
      await AppConfig.load();

      expect(AppConfig.serverIp, '172.20.10.11');
      expect(AppConfig.serverPort, 8000);
      expect(AppConfig.serverUrl, 'http://172.20.10.11:8000');
    });

    test('menyimpan dan memuat konfigurasi server baru', () async {
      SharedPreferences.setMockInitialValues({});

      await AppConfig.save(ip: '192.168.1.25', port: 9000);
      await AppConfig.load();

      expect(AppConfig.serverIp, '192.168.1.25');
      expect(AppConfig.serverPort, 9000);
      expect(AppConfig.serverUrl, 'http://192.168.1.25:9000');
      expect(AppConfig.ocrPredictEndpoint, 'http://192.168.1.25:9000/predict');
    });

    test('memuat konfigurasi yang sudah tersimpan sebelumnya', () async {
      SharedPreferences.setMockInitialValues({
        'server_ip': '10.0.0.7',
        'server_port': 8080,
      });

      await AppConfig.load();

      expect(AppConfig.serverUrl, 'http://10.0.0.7:8080');
    });
  });
}
