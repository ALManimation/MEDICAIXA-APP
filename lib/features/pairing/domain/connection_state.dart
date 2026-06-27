enum ConnectionStatus {
  disconnected,
  searching,
  connecting,
  connected,
  error,
}

class ConnectionStateInfo {
  final ConnectionStatus status;
  final String? ip;
  final String? deviceName;
  final String? firmwareVersion;
  final String? errorMessage;

  const ConnectionStateInfo({
    required this.status,
    this.ip,
    this.deviceName,
    this.firmwareVersion,
    this.errorMessage,
  });

  const ConnectionStateInfo.disconnected()
      : status = ConnectionStatus.disconnected,
        ip = null,
        deviceName = null,
        firmwareVersion = null,
        errorMessage = null;

  ConnectionStateInfo copyWith({
    ConnectionStatus? status,
    String? ip,
    String? deviceName,
    String? firmwareVersion,
    String? errorMessage,
  }) {
    return ConnectionStateInfo(
      status: status ?? this.status,
      ip: ip ?? this.ip,
      deviceName: deviceName ?? this.deviceName,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
