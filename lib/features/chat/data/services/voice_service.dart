import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';

/// Service that manages Speech-to-Text (STT), Text-to-Speech (TTS),
/// and audio feedback tones for chat interactions.
class VoiceService {
  final stt.SpeechToText _speech;
  final FlutterTts _tts;
  final AudioPlayer _audioPlayer;

  bool _isListening = false;
  bool get isListening => _isListening;

  bool _sttInitialized = false;

  VoiceService({
    stt.SpeechToText? speech,
    FlutterTts? tts,
    AudioPlayer? audioPlayer,
  })  : _speech = speech ?? stt.SpeechToText(),
        _tts = tts ?? FlutterTts(),
        _audioPlayer = audioPlayer ?? AudioPlayer() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (e) {
      debugPrint('VoiceService TTS initialization error: $e');
    }
  }

  /// Initialize Speech-to-Text engine, requesting permissions if necessary.
  Future<bool> initializeSTT() async {
    if (_sttInitialized) return true;
    try {
      final available = await _speech.initialize(
        onError: (val) {
          debugPrint('STT error: $val');
        },
        onStatus: (val) {
          debugPrint('STT status: $val');
        },
      );
      _sttInitialized = available;
      return available;
    } catch (e) {
      debugPrint('STT initialization exception (falling back): $e');
      _sttInitialized = false;
      return false;
    }
  }

  /// Starts listening to voice input and reports results and status changes.
  Future<void> startListening({
    required Function(String text) onResult,
    required Function(bool isListening) onListeningStatusChanged,
  }) async {
    if (_isListening) return;

    // Play feedback tone indicating that the recording/listening has begun
    await playFeedbackTone('start_listening');

    try {
      final hasPermission = await _speech.hasPermission;
      if (!hasPermission) {
        // Try initializing, which prompts for permission
        final initialized = await initializeSTT();
        if (!initialized) {
          debugPrint('STT microfone permission denied or STT unavailable');
          onListeningStatusChanged(false);
          await playFeedbackTone('error');
          return;
        }
      }

      // Ensure STT is initialized
      if (!_sttInitialized) {
        final initialized = await initializeSTT();
        if (!initialized) {
          onListeningStatusChanged(false);
          await playFeedbackTone('error');
          return;
        }
      }

      _isListening = true;
      onListeningStatusChanged(true);

      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
      );
    } catch (e) {
      debugPrint('STT startListening error (falling back): $e');
      // Graceful fallback: update state as if listening failed or is not available
      _isListening = false;
      onListeningStatusChanged(false);
      await playFeedbackTone('error');
    }
  }

  /// Stops listening to voice input.
  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await _speech.stop();
      _isListening = false;
    } catch (e) {
      debugPrint('STT stopListening error: $e');
      _isListening = false;
    }
  }

  /// Speaks the provided [text] using Text-to-Speech (TTS).
  Future<void> speak(String text) async {
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  /// Stops any ongoing TTS speech.
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }

  /// Set the TTS language/locale (e.g., 'pt-BR', 'en-US').
  Future<void> setLocale(String locale) async {
    try {
      await _tts.setLanguage(locale);
    } catch (e) {
      debugPrint('TTS setLocale error: $e');
    }
  }

  /// Set the TTS speech rate (0.0 to 1.0).
  Future<void> setRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate);
    } catch (e) {
      debugPrint('TTS setRate error: $e');
    }
  }

  /// Set the TTS pitch (0.5 to 2.0).
  Future<void> setPitch(double pitch) async {
    try {
      await _tts.setPitch(pitch);
    } catch (e) {
      debugPrint('TTS setPitch error: $e');
    }
  }

  /// Plays a short audio feedback tone based on the interaction state.
  /// Supported types: 'start_listening', 'success', 'error'.
  Future<void> playFeedbackTone(String type) async {
    try {
      String assetPath;
      switch (type) {
        case 'start_listening':
          assetPath = 'sounds/alarm_beep.wav';
          break;
        case 'success':
          assetPath = 'sounds/alarm_gentile.wav';
          break;
        case 'error':
          assetPath = 'sounds/alarm_urgente.wav';
          break;
        default:
          assetPath = 'sounds/alarm_beep.wav';
      }
      
      // audioplayers plays from assets using AssetSource (usually default root is 'assets/')
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      // Catch all exceptions (such as missing files or platform channel failure)
      // to guarantee that no voice operations crash the application.
      debugPrint('AudioPlayer playFeedbackTone error (gracefully caught): $e');
    }
  }
}
