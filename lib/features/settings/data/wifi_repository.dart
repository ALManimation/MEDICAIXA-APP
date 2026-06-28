import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:medicaixa_app/core/network/dio_client.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/features/pairing/presentation/pairing_notifier.dart';
import 'package:medicaixa_app/features/pairing/domain/connection_state.dart';

part 'wifi_repository.g.dart';

class WifiNetwork {
  final String ssid;
  final int? rssi;
  final int? channel;
  final bool? isOpen;

  const WifiNetwork({
    required this.ssid,
    this.rssi,
    this.channel,
    this.isOpen,
  });

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    return WifiNetwork(
      ssid: json['ssid'] as String? ?? '',
      rssi: json['rssi'] as int?,
      channel: json['channel'] as int?,
      isOpen: json['open'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ssid': ssid,
      if (rssi != null) 'rssi': rssi,
      if (channel != null) 'channel': channel,
      if (isOpen != null) 'open': isOpen,
    };
  }
}

class WifiRepository {
  final DioClient _dioClient;
  final Ref _ref;

  WifiRepository(this._dioClient, this._ref);

  bool _isConnected() {
    final connState = _ref.read(pairingNotifierProvider);
    return connState.status == ConnectionStatus.connected;
  }

  /// Scan available Wi-Fi networks in range
  /// GET /wifi_scan
  /// Returns: List<WifiNetwork> sorted by RSSI descending (strongest first)
  Future<List<WifiNetwork>> scanNetworks() async {
    if (!_isConnected()) {
      throw Exception('O dispositivo MediCaixa está desconectado.');
    }
    
    final response = await _dioClient.get('/wifi_scan');
    if (response.statusCode == 200) {
      if (response.data is List) {
        final list = response.data as List;
        final networks = list
            .map((item) => WifiNetwork.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        
        // Sort by RSSI descending (strongest signal first, e.g. -40dBm > -85dBm)
        networks.sort((a, b) {
          if (a.rssi == null) return 1;
          if (b.rssi == null) return -1;
          return b.rssi!.compareTo(a.rssi!);
        });
        return networks;
      }
      return [];
    } else {
      throw Exception('Erro ao escanear redes Wi-Fi (Status: ${response.statusCode})');
    }
  }

  /// List saved networks on the device
  /// GET /wifi_list
  /// Returns: List<WifiNetwork> (contains only SSIDs)
  Future<List<WifiNetwork>> getSavedNetworks() async {
    if (!_isConnected()) {
      throw Exception('O dispositivo MediCaixa está desconectado.');
    }

    final response = await _dioClient.get('/wifi_list');
    if (response.statusCode == 200) {
      if (response.data is List) {
        final list = response.data as List;
        return list
            .map((item) => WifiNetwork.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return [];
    } else {
      throw Exception('Erro ao obter redes salvas (Status: ${response.statusCode})');
    }
  }

  /// Add network credentials to the device
  /// POST /wifi_add
  /// Payload: {"ssid": "SSID", "password": "PASS"}
  Future<void> addNetwork(String ssid, String password) async {
    if (!_isConnected()) {
      throw Exception('O dispositivo MediCaixa está desconectado.');
    }

    final response = await _dioClient.post(
      '/wifi_add',
      data: {
        'ssid': ssid,
        'password': password,
      },
    );
    
    if (response.statusCode != 200 || response.data?.toString() != 'OK') {
      throw Exception('Falha ao salvar rede Wi-Fi na caixinha.');
    }
  }

  /// Forget/remove saved network credentials
  /// POST /wifi_remove
  /// Payload: {"ssid": "SSID"}
  Future<void> removeNetwork(String ssid) async {
    if (!_isConnected()) {
      throw Exception('O dispositivo MediCaixa está desconectado.');
    }

    final response = await _dioClient.post(
      '/wifi_remove',
      data: {'ssid': ssid},
    );

    if (response.statusCode != 200 || response.data?.toString() != 'OK') {
      throw Exception('Falha ao remover rede Wi-Fi da caixinha.');
    }
  }
}

@Riverpod(keepAlive: true)
WifiRepository wifiRepository(WifiRepositoryRef ref) {
  return WifiRepository(
    ref.watch(dioClientProvider),
    ref,
  );
}

/// Triggers Wi-Fi scanning in the background. Auto-disposed to avoid constant CPU scan cycles.
@riverpod
Future<List<WifiNetwork>> wifiScan(WifiScanRef ref) async {
  final repository = ref.watch(wifiRepositoryProvider);
  return repository.scanNetworks();
}

/// Fetches saved networks list.
@riverpod
Future<List<WifiNetwork>> savedWifiNetworks(SavedWifiNetworksRef ref) async {
  final repository = ref.watch(wifiRepositoryProvider);
  return repository.getSavedNetworks();
}

/// Mutator for Wi-Fi configurations (Add, Remove)
@riverpod
class WifiActionNotifier extends _$WifiActionNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> addNetwork(String ssid, String password) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(wifiRepositoryProvider);
      await repository.addNetwork(ssid, password);
      state = const AsyncValue.data(null);
      
      // Invalidate providers to trigger automatic UI refreshes
      ref.invalidate(savedWifiNetworksProvider);
      ref.invalidate(wifiScanProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> removeNetwork(String ssid) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(wifiRepositoryProvider);
      await repository.removeNetwork(ssid);
      state = const AsyncValue.data(null);
      
      // Invalidate providers to trigger automatic UI refreshes
      ref.invalidate(savedWifiNetworksProvider);
      ref.invalidate(wifiScanProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
