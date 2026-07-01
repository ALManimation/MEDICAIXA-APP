import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'voice_service.dart';

part 'voice_providers.g.dart';

@Riverpod(keepAlive: true)
VoiceService voiceService(VoiceServiceRef ref) {
  return VoiceService();
}
