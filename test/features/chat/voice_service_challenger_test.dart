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
  int listenCallCount = 0;
  int initializeCallCount = 0;
  int stopCallCount = 0;

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
    initializeCallCount++;
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
    listenCallCount++;
    if (onResult != null) onResultCallback = onResult;
    isListeningValue = true;
    if (onStatusCallback != null) {
      onStatusCallback!('listening');
    }
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    isListeningValue = false;
    if (onStatusCallback != null) {
      onStatusCallback!('notListening');
    }
  }

  @override
  Future<void> cancel() async {
    isListeningValue = false;
  }

  void triggerResult(String recognizedWords) {
    if (onResultCallback != null) {
      final words = SpeechRecognitionWords(recognizedWords, 1.0);
      final result = SpeechRecognitionResult([words], true);
      onResultCallback!(result);
    }
  }

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
  int speakCallCount = 0;
  int stopCallCount = 0;
  int setSpeechRateCallCount = 0;
  int setPitchCallCount = 0;

  bool shouldThrowOnInvalidRate = false;
  bool shouldThrowOnInvalidPitch = false;

  @override
  Future<dynamic> setLanguage(String lang) async {
    language = lang;
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    setSpeechRateCallCount++;
    if (shouldThrowOnInvalidRate && (rate < 0.0 || rate > 1.0)) {
      throw ArgumentError('Speech rate must be between 0.0 and 1.0');
    }
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
    setPitchCallCount++;
    if (shouldThrowOnInvalidPitch && (ptch < 0.5 || ptch > 2.0)) {
      throw ArgumentError('Pitch must be between 0.5 and 2.0');
    }
    pitch = ptch;
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    speakCallCount++;
    spokenText = text;
    isSpeaking = true;
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCallCount++;
    isSpeaking = false;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockAudioPlayer implements AudioPlayer {
  Source? playedSource;
  bool isPlaying = false;
  int playCallCount = 0;
  bool shouldThrowOnPlay = false;

  @override
  Future<void> play(Source source, {
    double? volume,
    dynamic balance,
    dynamic ctx,
    Duration? position,
    dynamic mode,
  }) async {
    playCallCount++;
    if (shouldThrowOnPlay) {
      throw Exception('Failed to play audio asset or missing source');
    }
    playedSource = source;
    isPlaying = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('VoiceService Challenger Edge Case & Stress Tests', () {
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

    // 1. Double/multiple start listening calls (prevent starting twice)
    test('Double startListening calls prevent starting twice and do not play tone twice', () async {
      final statuses = <bool>[];

      await voiceService.startListening(
        onResult: (_) {},
        onListeningStatusChanged: (status) {
          statuses.add(status);
        },
      );

      expect(voiceService.isListening, isTrue);
      expect(mockSpeech.listenCallCount, 1);
      expect(mockAudioPlayer.playCallCount, 1);

      await voiceService.startListening(
        onResult: (_) {},
        onListeningStatusChanged: (status) {
          statuses.add(status);
        },
      );

      expect(voiceService.isListening, isTrue);
      expect(mockSpeech.listenCallCount, 1);
      expect(mockAudioPlayer.playCallCount, 1);
      expect(statuses, [true]);
    });

    // 2. Audio playback failures or asset missing errors (should fail gracefully)
    test('Audio playback failures or asset missing errors are caught gracefully and do not block startListening', () async {
      mockAudioPlayer.shouldThrowOnPlay = true;

      final statuses = <bool>[];

      await voiceService.startListening(
        onResult: (_) {},
        onListeningStatusChanged: (status) {
          statuses.add(status);
        },
      );

      expect(voiceService.isListening, isTrue);
      expect(mockSpeech.listenCallCount, 1);
      expect(statuses, [true]);
    });

    test('playFeedbackTone catches exception gracefully and completes', () async {
      mockAudioPlayer.shouldThrowOnPlay = true;

      await expectLater(
        voiceService.playFeedbackTone('start_listening'),
        completes,
      );
    });

    // 3. Speed rate / pitch boundary limits (out of bounds values handling)
    test('Speed rate boundary limits do not crash the service when out of bounds values throw', () async {
      mockTts.shouldThrowOnInvalidRate = true;

      await voiceService.setRate(0.5);
      expect(mockTts.speechRate, 0.5);

      await expectLater(voiceService.setRate(-0.1), completes);
      expect(mockTts.speechRate, 0.5);

      await expectLater(voiceService.setRate(1.1), completes);
      expect(mockTts.speechRate, 0.5);
    });

    test('Pitch boundary limits do not crash the service when out of bounds values throw', () async {
      mockTts.shouldThrowOnInvalidPitch = true;

      await voiceService.setPitch(1.0);
      expect(mockTts.pitch, 1.0);

      await expectLater(voiceService.setPitch(0.4), completes);
      expect(mockTts.pitch, 1.0);

      await expectLater(voiceService.setPitch(2.1), completes);
      expect(mockTts.pitch, 1.0);
    });

    // 4. Rapid start/stop transitions
    test('Rapid start/stop transitions with awaits transition the state correctly', () async {
      final statuses = <bool>[];

      await voiceService.startListening(
        onResult: (_) {},
        onListeningStatusChanged: (status) {
          statuses.add(status);
        },
      );
      expect(voiceService.isListening, isTrue);

      await voiceService.stopListening();
      expect(voiceService.isListening, isFalse);

      await voiceService.startListening(
        onResult: (_) {},
        onListeningStatusChanged: (status) {
          statuses.add(status);
        },
      );
      expect(voiceService.isListening, isTrue);

      await voiceService.stopListening();
      expect(voiceService.isListening, isFalse);

      expect(mockSpeech.listenCallCount, 2);
      expect(mockSpeech.stopCallCount, 2);
      expect(statuses, [true, true]);
    });

    test('Calling stopListening when not listening does not change state or throw', () async {
      expect(voiceService.isListening, isFalse);

      await expectLater(voiceService.stopListening(), completes);

      expect(voiceService.isListening, isFalse);
      expect(mockSpeech.stopCallCount, 0);
    });

    test('Immediate stopListening call during startListening initialization (race condition)', () async {
      final statuses = <bool>[];

      final startFuture = voiceService.startListening(
        onResult: (_) {},
        onListeningStatusChanged: (status) {
          statuses.add(status);
        },
      );

      final stopFuture = voiceService.stopListening();

      await Future.wait([startFuture, stopFuture]);

      expect(voiceService.isListening, isTrue);
      expect(mockSpeech.listenCallCount, 1);
      expect(statuses, [true]);
    });

    // 5. Permissions denied state verification
    test('Permission initially denied and initialization fails -> plays error tone and stays offline', () async {
      mockSpeech.permissionValue = false;
      mockSpeech.initializedValue = false;

      final statuses = <bool>[];

      await voiceService.startListening(
        onResult: (_) {},
        onListeningStatusChanged: (status) {
          statuses.add(status);
        },
      );

      expect(voiceService.isListening, isFalse);
      expect(statuses, [false]);
      expect(mockSpeech.listenCallCount, 0);
      expect((mockAudioPlayer.playedSource as AssetSource).path, 'sounds/alarm_urgente.wav');
    });

    test('Permission initially denied but initialization succeeds -> starts listening successfully', () async {
      mockSpeech.permissionValue = false;
      mockSpeech.initializedValue = true;

      final statuses = <bool>[];

      await voiceService.startListening(
        onResult: (_) {},
        onListeningStatusChanged: (status) {
          statuses.add(status);
        },
      );

      expect(voiceService.isListening, isTrue);
      expect(mockSpeech.initializeCallCount, 1);
      expect(mockSpeech.listenCallCount, 1);
      expect(statuses, [true]);
      expect((mockAudioPlayer.playedSource as AssetSource).path, 'sounds/alarm_beep.wav');
    });
  });
}
