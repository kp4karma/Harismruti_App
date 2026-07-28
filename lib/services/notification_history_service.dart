import 'package:flutter/foundation.dart';
import 'package:harismruti/utils/storage_helper.dart';

class NotificationHistoryService {
  NotificationHistoryService._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static const int _maximumEntries = 100;

  static List<Map<String, dynamic>> get entries {
    final stored = StorageHelper.getValue<List>(
      key: StorageKeys.notificationHistory,
      defaultValue: const [],
    );
    return (stored ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static int get unreadCount =>
      entries.where((entry) => entry['is_read'] != true).length;

  static void save({
    required String id,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    final history = entries;
    final imageUrl = _firstText([
      data['image_url'],
      data['image'],
      data['picture'],
    ]);
    final existingIndex = history.indexWhere((item) => item['id'] == id);
    final entry = <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'image_url': imageUrl,
      'received_at': DateTime.now().toIso8601String(),
      'is_read': existingIndex >= 0
          ? history[existingIndex]['is_read'] == true
          : false,
      'data': data,
    };
    if (existingIndex >= 0) history.removeAt(existingIndex);
    history.insert(0, entry);
    if (history.length > _maximumEntries) {
      history.removeRange(_maximumEntries, history.length);
    }
    StorageHelper.setValue(
      key: StorageKeys.notificationHistory,
      value: history,
    );
    revision.value++;
  }

  static void markRead(String id) {
    final history = entries;
    final index = history.indexWhere((item) => item['id'] == id);
    if (index < 0 || history[index]['is_read'] == true) return;
    history[index]['is_read'] = true;
    StorageHelper.setValue(
      key: StorageKeys.notificationHistory,
      value: history,
    );
    revision.value++;
  }

  static void markAllRead() {
    final history = entries;
    var changed = false;
    for (final item in history) {
      if (item['is_read'] != true) {
        item['is_read'] = true;
        changed = true;
      }
    }
    if (!changed) return;
    StorageHelper.setValue(
      key: StorageKeys.notificationHistory,
      value: history,
    );
    revision.value++;
  }

  static String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
