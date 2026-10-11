import 'dart:developer' as developer;

class AppLogger {
  static void logInfo(String message) {
    developer.log(message, name: 'AppLogger', level: 800);
  }

  static void logError(String message) {
    developer.log(message, name: 'AppLogger', level: 1000);
  }

  static void logWarning(String message) {
    developer.log(message, name: 'AppLogger', level: 900);
  }

  static void logDebug(String message) {
    developer.log(message, name: 'AppLogger', level: 700);
  }
}
