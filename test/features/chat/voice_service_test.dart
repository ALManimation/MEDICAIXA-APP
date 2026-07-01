import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:medicaixa_app/features/chat/data/services/voice_service.dart';

class MockSpeechToText implements stt.SpeechToText {
  bool initializedValue = true;
  bool permissionValue = true;
  bool isListeningValue = false;
  
  stt.SpeechErrorListener? onErrorCallback;
  stt.SpeechStatusListener? onStatusCallback;
  stt.SpeechResultListener? onResultCallback;

  @override
  Future<bool> initialize({
    stt.SpeechErrorListener? onError,
    stt.SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = const Duration(seconds: 10),
    List<stt.SpeechConfigOption>? options,
  }) async {
    if (onError != null) onErrorCallback = onError;
    if (onStatus != null) onStatusCallback = onStatus;
    return initializedValue;
  }

  @override
  Future<bool> get hasPermission async => permissionValue;

  @override
  bool get isListening => isListeningValue;

  @override
  Future<void> listen({
    stt.SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    stt.SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    stt.ListenMode listenMode = stt.ListenMode.confirmation,
    sampleRate = 0,
    stt.SpeechListenOptions? listenOptions,
  }) async {
    if (onResult != null) onResultCallback = onResult;
    isListeningValue = true;
    if (onStatusCallback != null) {
      onStatusCallback!('listening');
    }
  }

  @override
  Future<void> stop() async {
    isListeningValue = false;
    if (onStatusCallback != null) {
      onStatusCallback!('notListening');
    }
  }

  @override
  Future<void> cancel() async {
    isListeningValue = false;
  }

  // Trigger result mock helper
  void triggerResult(String recognizedWords) {
    if (onResultCallback != null) {
      final words = SpeechRecognitionWords(recognizedWords, 1.0);
      final result = SpeechRecognitionResult([words], true);
      onResultCallback!(result);
    }
  }

  // Trigger error mock helper
  void triggerError(String errorMsg, bool permanent) {
    if (onErrorCallback != null) {
      final err = SpeechRecognitionError(errorMsg, permanent);
      onErrorCallback!(err);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockFlutterTts implements FlutterTts {
  String? language;
  double? speechRate;
  double? volume;
  double? pitch;
  String? spokenText;
  bool isSpeaking = false;

  @override
  Future<dynamic> setLanguage(String lang) async {
    language = lang;
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    speechRate = rate;
    return 1;
  }

  @override
  Future<dynamic> setVolume(double vol) async {
    volume = vol;
    return 1;
  }

  @override
  Future<dynamic> setPitch(double ptch) async {
    pitch = ptch;
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spokenText = text;
    isSpeaking = true;
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    isSpeaking = false;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockAudioPlayer implements AudioPlayer {
  Source? playedSource;
  bool isPlaying = false;

  @override
  Future<void> play(Source source, {
    double? volume,
    dynamic balance,
    dynamic ctx,
    Duration? position,
    dynamic mode,
  }) async {
    playedSource = source;
    isPlaying = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('VoiceService Tests', () {
    late MockSpeechToText mockSpeech;
    late MockFlutterTts mockTts;
    late MockAudioPlayer mockAudioPlayer;
    late VoiceService voiceService;

    setUp(() {
      mockSpeech = MockSpeechToText();
      mockTts = MockFlutterTts();
      mockAudioPlayer = MockAudioPlayer();

      voiceService = VoiceService(
        speech: mockSpeech,
        tts: mockTts,
        audioPlayer: mockAudioPlayer,
      );
    });

    test('Initializes TTS with default settings', () async {
      // Small delay to let async _initTts run
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(mockTts.language, 'pt-BR');
      expect(mockTts.speechRate, 0.5);
      expect(mockTts.volume, 1.0);
      expect(mockTts.pitch, 1.0);
    });

    test('plays feedback tones for different states', () async {
      await voiceService.playFeedbackTone('start_listening');
      expect(mockAudioPlayer.isPlaying, isTrue);
      expect(mockAudioPlayer.playedSource, isA<AssetSource>());
      expect((mockAudioPlayer.playedSource as AssetSource).path, 'sounds/alarm_beep.wav');

      await voiceService.playFeedbackTone('success');
      expect((mockAudioPlayer.playedSource as AssetSource).path, 'sounds/alarm_gentile.wav');

      await voiceService.playFeedbackTone('error');
      expect((mockAudioPlayer.playedSource as AssetSource).path, 'sounds/alarm_urgente.wav');
    });

    test('startListening triggers start tone, checks permission, and registers listeners', () async {
      String? recognizedResult;
      bool? isListeningStatus;

      await voiceService.startListening(
        onResult: (text) => recognizedResult = text,
        onListeningStatusChanged: (status) => isListeningStatus = status,
      );

      // Verify that start feedback tone was played
      expect((mockAudioPlayer.playedSource as AssetSource).path, 'sounds/alarm_beep.wav');
      expect(isListeningStatus, isTrue);
      expect(voiceService.isListening, isTrue);

      // Trigger recognition result
      mockSpeech.triggerResult('olá medicaixa');
      expect(recognizedResult, 'olá medicaixa');
    });

    test('stopListening calls stop on SpeechToText', () async {
      bool? isListeningStatus;

      await voiceService.startListening(
        onResult: (_) {},
        onListeningStatusChanged: (status) => isListeningStatus = status,
      );
      expect(isListeningStatus, isTrue);
      expect(voiceService.isListening, isTrue);

      await voiceService.stopListening();
      expect(voiceService.isListening, isFalse);
    });

    test('Handles permission denial gracefully by playing error tone and updating state', () async {
      mockSpeech.permissionValue = false;
      mockSpeech.initializedValue = false;

      bool? isListeningStatus;

      await voiceService.startListening(
        onResult: (_) {},
        onListeningStatusChanged: (status) => isListeningStatus = status,
      );

      expect(isListeningStatus, isFalse);
      expect(voiceService.isListening, isFalse);
      // Feedback tone changes to error tone
      expect((mockAudioPlayer.playedSource as AssetSource).path, 'sounds/alarm_urgente.wav');
    });

    test('TTS control methods invoke correct native bindings', () async {
      await voiceService.speak('Olá, paciente');
      expect(mockTts.spokenText, 'Olá, paciente');
      expect(mockTts.isSpeaking, isTrue);

      await voiceService.stopSpeaking();
      expect(mockTts.isSpeaking, isFalse);

      await voiceService.setLocale('en-US');
      expect(mockTts.language, 'en-US');

      await voiceService.setRate(0.85);
      expect(mockTts.speechRate, 0.85);

      await voiceService.setPitch(1.5);
      expect(mockTts.pitch, 1.5);
    });
  });
}
