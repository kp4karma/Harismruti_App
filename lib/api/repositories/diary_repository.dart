import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/api/api_endpoints.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/my_diary_controller.dart';

class DiaryRepository {
  const DiaryRepository();

  Future<List<DiaryEntry>> getEntries() async {
    final response = await ApiClient.get(ApiEndpoints.myDiary);
    final payload = asJsonMap(response.data);
    final source = payload['data'] ?? payload['items'] ?? payload['diary'];
    final items = source is List
        ? source
        : response.data is List
        ? response.data as List
        : const [];
    return items
        .whereType<Map>()
        .map((item) => DiaryEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<DiaryEntry?> saveEntry(DiaryEntry entry) async {
    final data = entry.toJson();
    final response = await ApiClient.post(ApiEndpoints.myDiary, data: data);
    return _entryFromResponse(response.data);
  }

  Future<void> deleteEntry(String dateKey) async {
    await ApiClient.delete(ApiEndpoints.myDiaryEntry(dateKey));
  }

  DiaryEntry? _entryFromResponse(dynamic data) {
    final payload = asJsonMap(data);
    final source = payload['data'] ?? payload['entry'] ?? payload;
    if (source is Map) {
      return DiaryEntry.fromJson(Map<String, dynamic>.from(source));
    }
    return null;
  }
}
