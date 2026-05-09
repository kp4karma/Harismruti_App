import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class SecureLogger {
  // Use fromBase64 instead of fromUtf8
  static final _key = encrypt.Key.fromBase64('Qr8N7YXVoJHkRFiQXAG9bg==');
  static final _iv = encrypt.IV.fromBase64('8Kqzl+SIdlv2iDx97mdYOg==');
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));

  static Future<String> _getLogFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/secure_error_logs.txt';
  }

  static Future<void> write(String log) async {
    final path = await _getLogFilePath();
    final file = File(path);
    final timestamp = DateTime.now().toIso8601String();
    final encrypted = _encrypter.encrypt('[$timestamp] $log', iv: _iv);

    await file.writeAsString('${encrypted.base64}\n', mode: FileMode.append);
  }

  static Future<String> readLogs() async {
    final path = await _getLogFilePath();
    final file = File(path);

    if (!await file.exists()) return 'No logs found.';

    final lines = await file.readAsLines();
    final decryptedLogs = lines.map((line) {
      try {
        return _encrypter.decrypt64(line, iv: _iv);
      } catch (_) {
        return '⚠️ Failed to decrypt a log entry.';
      }
    }).join('\n');

    return decryptedLogs;
  }

  static Future<void> clearLogs() async {
    final path = await _getLogFilePath();
    final file = File(path);
    if (await file.exists()) {
      await file.writeAsString('');
    }
  }
}
