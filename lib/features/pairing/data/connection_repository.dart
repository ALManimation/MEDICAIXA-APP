import 'package:drift/drift.dart';
import '../../../core/database/database.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mdns_discovery.dart';
import '../../../core/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connection_repository.g.dart';

class ConnectionRepository {
  final AppDatabase _db;
  final DioClient _dioClient;

  ConnectionRepository(this._db, this._dioClient);

  Future<String?> getSavedDeviceIp() async {
    final settingsList = await _db.select(_db.settings).get();
    if (settingsList.isEmpty) return null;
    return settingsList.first.deviceIp;
  }

  Future<void> saveDeviceIp(String? ip) async {
    final settingsList = await _db.select(_db.settings).get();
    if (settingsList.isEmpty) {
      await _db.into(_db.settings).insert(
            SettingsCompanion.insert(
              deviceIp: Value(ip),
            ),
          );
    } else {
      final existing = settingsList.first;
      await _db.update(_db.settings).replace(
            existing.copyWith(deviceIp: Value(ip)),
          );
    }
    if (ip != null) {
      _dioClient.setBaseUrl(ip);
    }
  }

  Future<Map<String, dynamic>?> pingDevice(String ip) async {
    try {
      final oldUrl = _dioClient.baseUrl;
      _dioClient.setBaseUrl(ip);
      final response = await _dioClient.get('/api/status');
      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }
      _dioClient.setBaseUrl(oldUrl ?? '');
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> discover() async {
    return await MdnsDiscovery.discoverMediCaixa();
  }
}

@Riverpod(keepAlive: true)
ConnectionRepository connectionRepository(ConnectionRepositoryRef ref) {
  // Wait, we need to access database and dioClient from core_providers.dart!
  // Wait, we can import core_providers.dart and use ref.watch.
  // Yes!
  return ConnectionRepository(
    ref.watch(databaseProvider),
    ref.watch(dioClientProvider),
  );
}
