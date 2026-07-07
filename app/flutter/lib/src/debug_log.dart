import 'package:flutter/foundation.dart';

class AppDebugLog {
  AppDebugLog._();

  static void log(String message) {
    final line = '${_timestamp()} $message';
    debugPrint(line);
  }

  static String _timestamp() {
    final now = DateTime.now();
    final hours = now.hour.toString().padLeft(2, '0');
    final minutes = now.minute.toString().padLeft(2, '0');
    final seconds = now.second.toString().padLeft(2, '0');
    return '[$hours:$minutes:$seconds]';
  }
}
