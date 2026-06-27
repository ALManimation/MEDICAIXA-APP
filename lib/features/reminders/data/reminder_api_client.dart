import '../../../core/network/dio_client.dart';
import 'reminder_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/providers/core_providers.dart';

part 'reminder_api_client.g.dart';

class ReminderApiClient {
  final DioClient _dioClient;

  ReminderApiClient(this._dioClient);

  Future<List<ReminderModel>> fetchReminders() async {
    final response = await _dioClient.get('/api/reminders');
    if (response.statusCode == 200 && response.data is List) {
      final list = response.data as List;
      return list.map((json) => ReminderModel.fromJson(json as Map<String, dynamic>)).toList();
    }
    throw Exception('Falha ao buscar lembretes do dispositivo');
  }

  Future<int> addReminder(ReminderModel reminder) async {
    final payload = reminder.toJson();
    payload.remove('id'); // ESP32 auto-generates ID
    final response = await _dioClient.post('/api/reminders', data: payload);
    if (response.statusCode == 200 && response.data is Map) {
      final data = response.data as Map;
      if (data['ok'] == true && data.containsKey('id')) {
        return data['id'] as int;
      }
    }
    throw Exception('Falha ao adicionar lembrete no dispositivo');
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    final response = await _dioClient.post('/api/reminders/update', data: reminder.toJson());
    if (response.statusCode != 200 || (response.data is Map && (response.data as Map)['ok'] != true)) {
      throw Exception('Falha ao atualizar lembrete no dispositivo');
    }
  }

  Future<void> removeReminder(int id) async {
    final response = await _dioClient.post('/api/reminders/remove', data: {'id': id});
    if (response.statusCode != 200 || (response.data is Map && (response.data as Map)['ok'] != true)) {
      throw Exception('Falha ao remover lembrete no dispositivo');
    }
  }

  Future<void> toggleReminder(int id, bool enabled) async {
    final response = await _dioClient.post('/api/reminders/toggle', data: {'id': id, 'enabled': enabled});
    if (response.statusCode != 200 || (response.data is Map && (response.data as Map)['ok'] != true)) {
      throw Exception('Falha ao alternar estado do lembrete no dispositivo');
    }
  }

  Future<void> completeReminder(int id) async {
    final response = await _dioClient.post('/api/reminders/complete', data: {'id': id});
    if (response.statusCode != 200 || (response.data is Map && (response.data as Map)['ok'] != true)) {
      throw Exception('Falha ao marcar lembrete como concluído no dispositivo');
    }
  }
}

@Riverpod(keepAlive: true)
ReminderApiClient reminderApiClient(ReminderApiClientRef ref) {
  return ReminderApiClient(ref.watch(dioClientProvider));
}
