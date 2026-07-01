import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/pairing/domain/connection_state.dart';

part 'connection_providers.g.dart';

@Riverpod(keepAlive: true)
class DeviceConnectionState extends _$DeviceConnectionState {
  @override
  ConnectionStateInfo build() {
    return const ConnectionStateInfo.disconnected();
  }

  void updateState(ConnectionStateInfo newState) {
    state = newState;
  }
}
