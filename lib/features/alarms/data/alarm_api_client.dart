import '../../../core/network/dio_client.dart';
import 'alarm_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/providers/core_providers.dart';

part 'alarm_api_client.g.dart';

class AlarmApiClient {
  final DioClient _dioClient;

  AlarmApiClient(this._dioClient);

  Future<List<AlarmModel>> fetchAlarms() async {
    final response = await _dioClient.get('/alarms');
    if (response.statusCode == 200 && response.data is List) {
      final list = response.data as List;
      return list.map((json) => AlarmModel.fromJson(json as Map<String, dynamic>)).toList();
    }
    throw Exception('Falha ao buscar alarmes do dispositivo');
  }

  Future<int> addAlarm(AlarmModel alarm) async {
    final payload = alarm.toJson();
    payload.remove('id'); // ESP32 auto-generates ID
    final response = await _dioClient.post('/add', data: payload);
    if (response.statusCode == 200 && response.data is Map) {
      final data = response.data as Map;
      if (data['ok'] == true && data.containsKey('id')) {
        return data['id'] as int;
      }
    }
    throw Exception('Falha ao adicionar alarme no dispositivo');
  }

  Future<void> updateAlarm(AlarmModel alarm) async {
    final response = await _dioClient.post('/update', data: alarm.toJson());
    if (response.statusCode != 200 || (response.data is Map && (response.data as Map)['ok'] != true)) {
      throw Exception('Falha ao atualizar alarme no dispositivo');
    }
  }

  Future<void> removeAlarm(int id) async {
    final response = await _dioClient.post('/remove', data: {'id': id});
    if (response.statusCode != 200 || (response.data is Map && (response.data as Map)['ok'] != true)) {
      throw Exception('Falha ao remover alarme no dispositivo');
    }
  }

  Future<void> toggleAlarm(int id, bool enabled) async {
    final response = await _dioClient.post('/toggle', data: {'id': id, 'enabled': enabled});
    if (response.statusCode != 200 || (response.data is Map && (response.data as Map)['ok'] != true)) {
      throw Exception('Falha ao alternar estado do alarme no dispositivo');
    }
  }

  Future<void> markTaken(int id, {double? qty}) async {
    final payload = <String, dynamic>{'id': id};
    if (qty != null) {
      payload['qty'] = qty;
    }
    final response = await _dioClient.post('/mark_taken', data: payload);
    if (response.statusCode != 200 || (response.data is Map && (response.data as Map)['ok'] != true)) {
      throw Exception('Falha ao marcar alarme como tomado no dispositivo');
    }
  }

  Future<void> markSkipped(int id) async {
    final response = await _dioClient.post('/mark_skipped', data: {'id': id});
    if (response.statusCode != 200 || (response.data is Map && (response.data as Map)['ok'] != true)) {
      throw Exception('Falha ao marcar alarme como não tomado no dispositivo');
    }
  }

  Future<void> takePrn(int id) async {
    final response = await _dioClient.post('/take_prn', data: {'id': id});
    if (response.statusCode != 200 || (response.data is Map && (response.data as Map)['ok'] != true)) {
      throw Exception('Falha ao registrar dose sob demanda no dispositivo');
    }
  }

  Future<void> pauseAlarm(int id, int pauseUntilEpoch) async {
    final response = await _dioClient.post('/pause', data: {'id': id, 'pause_until': pauseUntilEpoch});
    if (response.statusCode != 200 || (response.data is Map && (response.data as Map)['ok'] != true)) {
      throw Exception('Falha ao pausar alarme no dispositivo');
    }
  }

  Future<void> snoozeAlarm(int id, int minutes) async {
    final response = await _dioClient.post('/snooze', data: {'id': id, 'minutes': minutes});
    if (response.statusCode != 200 || (response.data is Map && (response.data as Map)['ok'] != true)) {
      throw Exception('Falha ao adiar alarme no dispositivo');
    }
  }
}

@Riverpod(keepAlive: true)
AlarmApiClient alarmApiClient(AlarmApiClientRef ref) {
  return AlarmApiClient(ref.watch(dioClientProvider));
}
