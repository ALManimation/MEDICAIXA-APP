class AppConstants {
  AppConstants._();

  // Network and Sync
  static const String mdnsTargetName = 'medicaixa';
  static const String defaultHostname = 'medicaixa2.local';
  static const int defaultPort = 80;
  static const int requestTimeoutMs = 5000;
  static const Duration syncInterval = Duration(seconds: 30);

  // Range IDs
  static const int localIdOffset = 256;

  // Translation keys / App defaults
  static const String defaultLanguage = 'pt';
}
