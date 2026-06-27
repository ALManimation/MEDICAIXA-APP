import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/connection_repository.dart';
import '../domain/connection_state.dart';

part 'pairing_notifier.g.dart';

@riverpod
class PairingNotifier extends _$PairingNotifier {
  late final ConnectionRepository _repo;

  @override
  ConnectionStateInfo build() {
    _repo = ref.watch(connectionRepositoryProvider);
    _autoConnect();
    return const ConnectionStateInfo.disconnected();
  }

  Future<void> _autoConnect() async {
    final savedIp = await _repo.getSavedDeviceIp();
    if (savedIp != null && savedIp.isNotEmpty) {
      state = state.copyWith(status: ConnectionStatus.connecting, ip: savedIp);
      final statusMap = await _repo.pingDevice(savedIp);
      if (statusMap != null) {
        final version = statusMap['firmware_version']?.toString() ?? 'v0.90';
        state = state.copyWith(
          status: ConnectionStatus.connected,
          ip: savedIp,
          deviceName: 'MediCaixa',
          firmwareVersion: version,
        );
      } else {
        state = state.copyWith(
          status: ConnectionStatus.disconnected,
          errorMessage: 'Salvo: caixinha offline',
        );
      }
    }
  }

  Future<bool> discoverAndConnect() async {
    state = state.copyWith(status: ConnectionStatus.searching, errorMessage: null);

    final ip = await _repo.discover();
    if (ip == null) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'Dispositivo MediCaixa não encontrado na rede local',
      );
      return false;
    }

    return await connectManual(ip);
  }

  Future<bool> connectManual(String ip) async {
    // Format IP to ensure it starts with http:// and ends with no trailing slash
    var formattedIp = ip.trim();
    if (!formattedIp.startsWith('http://') && !formattedIp.startsWith('https://')) {
      formattedIp = 'http://$formattedIp';
    }
    if (formattedIp.endsWith('/')) {
      formattedIp = formattedIp.substring(0, formattedIp.length - 1);
    }

    state = state.copyWith(status: ConnectionStatus.connecting, ip: formattedIp, errorMessage: null);

    final statusMap = await _repo.pingDevice(formattedIp);
    if (statusMap != null) {
      final version = statusMap['firmware_version']?.toString() ?? 'v0.90';
      await _repo.saveDeviceIp(formattedIp);
      state = state.copyWith(
        status: ConnectionStatus.connected,
        ip: formattedIp,
        deviceName: 'MediCaixa',
        firmwareVersion: version,
      );
      return true;
    } else {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'Não foi possível conectar ao IP: $formattedIp',
      );
      return false;
    }
  }

  Future<void> useStandalone() async {
    await _repo.saveDeviceIp(null);
    state = const ConnectionStateInfo.disconnected();
  }

  void disconnect() {
    _repo.saveDeviceIp(null);
    state = const ConnectionStateInfo.disconnected();
  }
}
