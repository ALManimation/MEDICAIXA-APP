import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../chat/domain/services/llm_service.dart';
import '../../../settings/data/settings_repository.dart';
import 'gemini_llm_service.dart';
import 'local_llm_service.dart';

/// Hybrid LLM Service that automatically chooses between Gemini and Local LLM fallback
/// based on the availability of a Gemini API key and active internet connectivity.
class HybridLlmService implements LlmService {
  final Ref _ref;
  final GeminiLlmService _geminiLlmService;
  final LocalLlmService _localLlmService;

  HybridLlmService(this._ref)
      : _geminiLlmService = GeminiLlmService(_ref),
        _localLlmService = LocalLlmService();

  @override
  Future<LlmResponse> generateResponse(
    String message, {
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? systemContext,
  }) async {
    // 1. Check if Gemini API key exists
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final settings = await settingsRepo.getSettings();
    final apiKey = settings.geminiApiKey;

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('HybridLlmService: Gemini API key not configured. Falling back to LocalLlmService.');
      return _localLlmService.generateResponse(message, history: history, systemContext: systemContext);
    }

    // 2. Check connectivity
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult.any((result) => result != ConnectivityResult.none);

      if (!hasConnection) {
        debugPrint('HybridLlmService: No internet connection. Falling back to LocalLlmService.');
        final response = await _localLlmService.generateResponse(message, history: history, systemContext: systemContext);
        return LlmResponse(
          message: '[Modo Offline] ${response.message}',
          actions: response.actions,
          provider: 'local',
        );
      }
    } catch (e) {
      debugPrint('HybridLlmService: Connectivity check failed: $e. Falling back to LocalLlmService.');
      return _localLlmService.generateResponse(message, history: history, systemContext: systemContext);
    }

    // 3. Attempt to use GeminiLlmService
    try {
      return await _geminiLlmService.generateResponse(message, history: history, systemContext: systemContext);
    } catch (e) {
      debugPrint('HybridLlmService: GeminiLlmService execution failed: $e. Falling back to LocalLlmService.');
      final response = await _localLlmService.generateResponse(message, history: history, systemContext: systemContext);
      return LlmResponse(
        message: '[Erro no Gemini - Executando Localmente] ${response.message}',
        actions: response.actions,
        provider: 'local',
      );
    }
  }
}
