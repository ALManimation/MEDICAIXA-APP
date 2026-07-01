import '../../../chat/domain/services/llm_service.dart';

/// Local offline LLM fallback service that uses simple rule-based
/// and regex matching to process commands.
class LocalLlmService implements LlmService {
  @override
  Future<LlmResponse> generateResponse(
    String message, {
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? systemContext,
  }) async {
    final lower = _removeAccents(message.toLowerCase()).trim();

    // 1. "take" / "tomar"
    if (RegExp(r'\b(tomar|tomei|take|mark.*taken|marcar.*tomado)\b').hasMatch(lower)) {
      int index = 0;
      final match = RegExp(r'\b(alarme|alarm|index|remedio|remedio)\s*(\d+)\b').firstMatch(lower);
      if (match != null) {
        final parsed = int.tryParse(match.group(2) ?? '');
        if (parsed != null && parsed > 0) {
          index = parsed - 1;
        }
      }
      return LlmResponse(
        message: 'Registrando a tomada do seu medicamento (Alarme ${index + 1}).',
        actions: [
          LlmAction(type: 'mark_taken', params: {'index': index})
        ],
        provider: 'local',
      );
    }

    // 2. "snooze" / "adiar"
    if (RegExp(r'\b(snooze|adiar|atrasar|soneca|deixar.*depois|mais.*tarde)\b').hasMatch(lower)) {
      int index = 0;
      int minutes = 30; // Default snooze minutes
      
      final idxMatch = RegExp(r'\b(alarme|alarm|index)\s*(\d+)\b').firstMatch(lower);
      if (idxMatch != null) {
        final parsed = int.tryParse(idxMatch.group(2) ?? '');
        if (parsed != null && parsed > 0) {
          index = parsed - 1;
        }
      }

      final minMatch = RegExp(r'\b(\d+)\s*(minutos|minutos|mins|min|minutes)\b').firstMatch(lower);
      if (minMatch != null) {
        final parsed = int.tryParse(minMatch.group(1) ?? '');
        if (parsed != null && parsed > 0) {
          minutes = parsed;
        }
      }

      return LlmResponse(
        message: 'Entendido. Vou adiar o alarme ${index + 1} em $minutes minutos.',
        actions: [
          LlmAction(type: 'snooze_alarm', params: {'index': index, 'minutes': minutes})
        ],
        provider: 'local',
      );
    }

    // 3. "dismiss" / "ignorar" / "pular" / "cancelar"
    if (RegExp(r'\b(dismiss|ignorar|pular|cancelar|deixar.*pra.*la)\b').hasMatch(lower)) {
      int index = 0;
      final match = RegExp(r'\b(alarme|alarm|index)\s*(\d+)\b').firstMatch(lower);
      if (match != null) {
        final parsed = int.tryParse(match.group(2) ?? '');
        if (parsed != null && parsed > 0) {
          index = parsed - 1;
        }
      }
      return LlmResponse(
        message: 'Tudo bem, o alarme ${index + 1} foi desativado/ignorado por agora.',
        actions: [
          LlmAction(type: 'toggle_alarm', params: {'index': index})
        ],
        provider: 'local',
      );
    }

    // 4. "create alarm" / "criar alarme"
    if (RegExp(r'\b(criar|novo|adicionar|create|add)\s*(alarme|alarm|remedio|lembrete)\b').hasMatch(lower)) {
      const name = 'Novo Alarme';
      int hour = 8;
      int minute = 0;

      final timeMatch = RegExp(r'\b(\d{1,2})[:h](\d{2})\b').firstMatch(lower);
      if (timeMatch != null) {
        hour = int.tryParse(timeMatch.group(1) ?? '') ?? 8;
        minute = int.tryParse(timeMatch.group(2) ?? '') ?? 0;
      } else {
        final hourOnlyMatch = RegExp(r'\b(\d{1,2})\s*(horas|hrs|h|hours)\b').firstMatch(lower);
        if (hourOnlyMatch != null) {
          hour = int.tryParse(hourOnlyMatch.group(1) ?? '') ?? 8;
        }
      }

      return LlmResponse(
        message: 'Claro! Vou programar um novo alarme para as ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}.',
        actions: [
          LlmAction(
            type: 'add_alarm',
            params: {
              'name': name,
              'hour': hour,
              'minute': minute,
              'quantity': 1.0,
              'days': [0, 1, 2, 3, 4, 5, 6],
              'color': 'blue',
            },
          )
        ],
        provider: 'local',
      );
    }

    // 5. "list alarms" / "listar alarmes"
    if (RegExp(r'\b(listar|ver|list|mostrar|meus)\s*(alarmes|alarms|remedios|medicamentos)\b').hasMatch(lower)) {
      return LlmResponse(
        message: 'Aqui estão os seus alarmes programados. No momento, o processamento local está ativo.',
        actions: [
          LlmAction(type: 'list_alarms', params: const {})
        ],
        provider: 'local',
      );
    }

    // Default conversational reply
    return LlmResponse(
      message: "Olá! No momento estou em modo offline/local. Posso te ajudar a tomar, adiar, ignorar, criar ou listar alarmes se você usar comandos simples como 'tomar alarme 1' ou 'criar alarme as 10:00'.",
      actions: const [],
      provider: 'local',
    );
  }

  String _removeAccents(String str) {
    const withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    const withoutDia = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }
}
