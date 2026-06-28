
enum VoiceState {
  disconnected,
  connecting,
  connected,
  listening,
  thinking,
  speaking,
  error,
  uninitialized;

  static VoiceState fromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'conectando':
        return VoiceState.connecting;
      case 'conectado':
        return VoiceState.connected;
      case 'ouvindo':
        return VoiceState.listening;
      case 'pensando':
        return VoiceState.thinking;
      case 'falando':
        return VoiceState.speaking;
      case 'erro':
        return VoiceState.error;
      case 'não inicializado':
      case 'nao inicializado':
        return VoiceState.uninitialized;
      case 'desconectado':
      default:
        return VoiceState.disconnected;
    }
  }

  String get label {
    switch (this) {
      case VoiceState.connecting:
        return 'Conectando...';
      case VoiceState.connected:
        return 'Conectado';
      case VoiceState.listening:
        return 'Ouvindo...';
      case VoiceState.thinking:
        return 'Pensando...';
      case VoiceState.speaking:
        return 'Falando...';
      case VoiceState.error:
        return 'Erro de Conexão';
      case VoiceState.uninitialized:
        return 'Não Inicializado';
      case VoiceState.disconnected:
        return 'Desconectado';
    }
  }
}

class VoiceStatus {
  final VoiceState state;
  final bool connected;
  final String activationCode;
  final bool hasCredentials;
  final String wakeWord;

  VoiceStatus({
    required this.state,
    required this.connected,
    required this.activationCode,
    required this.hasCredentials,
    required this.wakeWord,
  });

  factory VoiceStatus.fromJson(Map<String, dynamic> json) {
    return VoiceStatus(
      state: VoiceState.fromString(json['state']?.toString() ?? 'desconectado'),
      connected: json['connected'] == true,
      activationCode: json['activation_code']?.toString() ?? '',
      hasCredentials: json['has_credentials'] == true,
      wakeWord: json['wake_word']?.toString() ?? 'sophia',
    );
  }
}

class DeviceDateTime {
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final int second;

  const DeviceDateTime({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.second,
  });

  factory DeviceDateTime.fromJson(Map<String, dynamic> json) {
    return DeviceDateTime(
      year: json['year'] as int? ?? DateTime.now().year,
      month: json['month'] as int? ?? DateTime.now().month,
      day: json['day'] as int? ?? DateTime.now().day,
      hour: json['hour'] as int? ?? DateTime.now().hour,
      minute: json['minute'] as int? ?? DateTime.now().minute,
      second: json['second'] as int? ?? DateTime.now().second,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'month': month,
      'day': day,
      'hour': hour,
      'minute': minute,
      'second': second,
    };
  }

  DateTime toDateTime() => DateTime(year, month, day, hour, minute, second);

  factory DeviceDateTime.fromDateTime(DateTime dt) {
    return DeviceDateTime(
      year: dt.year,
      month: dt.month,
      day: dt.day,
      hour: dt.hour,
      minute: dt.minute,
      second: dt.second,
    );
  }
}

/// Maps C++ alarmSound indices to UI values
enum RingtoneType {
  gentile('Gentil'),
  alerta('Alerta'),
  melodia('Melodia'),
  urgente('Urgente'),
  musical('Musical');

  final String label;

  const RingtoneType(this.label);

  static RingtoneType fromIndex(int index) {
    return RingtoneType.values.firstWhere(
      (r) => r.index == index,
      orElse: () => RingtoneType.alerta,
    );
  }
}

/// Maps repeat intervals to alarmSpacingMs
enum AlarmSpacingInterval {
  oneSecond(1000, '1s'),
  threeSeconds(3000, '3s'),
  sixSeconds(6000, '6s'),
  tenSeconds(10000, '10s');

  final int ms;
  final String label;

  const AlarmSpacingInterval(this.ms, this.label);

  static AlarmSpacingInterval fromMs(int ms) {
    return AlarmSpacingInterval.values.firstWhere(
      (i) => i.ms == ms,
      orElse: () => AlarmSpacingInterval.tenSeconds,
    );
  }
}
