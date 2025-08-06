import 'package:flutter/services.dart';

class SQLServerBridge {
  static const MethodChannel _channel = MethodChannel('com.example.vo_test');

  Future<String> fetchData() async {
    try {
      final String result = await _channel.invokeMethod('getData');
      return result;
    } on PlatformException catch (e) {
      return "Platform error: ${e.message}";
    } catch (e) {
      return "Unexpected error: $e";
    }
  }
}
