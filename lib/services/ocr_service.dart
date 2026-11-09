import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class OCRService {
  static Future<bool> checkServerConnection() async {
    try {
      final response = await http
          .get(Uri.parse(AppConfig.ocrHealthEndpoint))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<OCRResponse> predictReceipt(String imagePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConfig.ocrPredictEndpoint),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', imagePath),
      );

      request.headers['Content-Type'] = 'multipart/form-data';

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Server took too long to respond.');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return OCRResponse.fromJson(json);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('Cannot connect to server. Check IP and port. Error: ${e.message}');
    } catch (e) {
      throw Exception('Prediction error: ${e.toString()}');
    }
  }
}
