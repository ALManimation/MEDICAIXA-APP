import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../chat/domain/services/llm_service.dart';
import '../../domain/services/action_executor.dart';
import 'gemini_llm_service.dart';
import 'local_llm_service.dart';
import 'hybrid_llm_service.dart';

part 'llm_providers.g.dart';

@Riverpod(keepAlive: true)
ActionExecutor actionExecutor(ActionExecutorRef ref) {
  return ActionExecutor(ref);
}

@Riverpod(keepAlive: true)
LlmService geminiLlmService(GeminiLlmServiceRef ref) {
  return GeminiLlmService(ref);
}

@Riverpod(keepAlive: true)
LlmService localLlmService(LocalLlmServiceRef ref) {
  return LocalLlmService();
}

@Riverpod(keepAlive: true)
LlmService hybridLlmService(HybridLlmServiceRef ref) {
  return HybridLlmService(ref);
}
