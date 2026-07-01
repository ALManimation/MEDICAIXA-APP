import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../chat/domain/services/llm_service.dart';
import '../../../settings/data/settings_repository.dart';
import '../../../alarms/data/alarm_repository.dart';
import '../../../medications/data/medication_repository.dart';
import '../../../reminders/data/reminder_repository.dart';

/// Gemini-based implementation of the LLM Service.
class GeminiLlmService implements LlmService {
  final Ref _ref;

  GeminiLlmService(this._ref);

  @override
  Future<LlmResponse> generateResponse(
    String message, {
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? systemContext,
  }) async {
    // 1. Fetch settings and API key
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final settings = await settingsRepo.getSettings();
    final apiKey = settings.geminiApiKey;

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured.');
    }

    // 2. Fetch context information
    final patientName = settings.patientName;
    final deviceCurrentTime = DateTime.now().toLocal().toIso8601String();

    // Serialize Alarms (both active and inactive)
    final alarmRepo = _ref.read(alarmRepositoryProvider);
    final alarms = await alarmRepo.getAllAlarms();
    final alarmsJsonList = alarms.asMap().entries.map((entry) {
      final index = entry.key;
      final a = entry.value;
      return {
        'index': index,
        'id': a.id,
        'name': a.name,
        'med_name': a.medName,
        'hour': a.hour,
        'minute': a.minute,
        'enabled': a.enabled,
        'active': a.active,
        'quantity': a.quantity,
        'dosage': a.dosage,
        'color': a.color,
        'type': a.type,
        'days': a.days,
        'start_date': a.startDate,
        'duration_days': a.durationDays,
      };
    }).toList();

    // Serialize Medications
    final medRepo = _ref.read(medicationRepositoryProvider);
    final medications = await medRepo.getAllMedications();
    final medicationsJsonList = medications.map((m) => {
      'name': m.name,
      'color': m.color,
      'type': m.type,
      'dosage': m.dosage,
    }).toList();

    // Serialize Active Reminders
    final reminderRepo = _ref.read(reminderRepositoryProvider);
    final allReminders = await reminderRepo.getAllReminders();
    final today = DateTime.now();
    final activeReminders = allReminders.where((r) => reminderRepo.isReminderActiveOnDate(r, today)).toList();
    final remindersJsonList = activeReminders.asMap().entries.map((entry) {
      final index = entry.key;
      final r = entry.value;
      return {
        'index': index,
        'id': r.id,
        'title': r.title,
        'description': r.description,
        'enabled': r.enabled,
        'has_time': r.hasTime,
        'hour': r.hour,
        'minute': r.minute,
        'period': r.period,
        'interval': r.interval,
        'start_date': r.startDate,
        'notify_days_before': r.notifyDaysBefore,
        'color': r.color,
      };
    }).toList();

    // Build strict system prompt
    final systemPrompt = '''
Você é a assistente virtual da MediCaixa, o organizador inteligente de medicamentos e lembretes de saúde do(a) paciente $patientName.
Você deve se comunicar de forma extremamente educada, empática e prestativa, cumprimentando o(a) paciente no início de cada resposta.

=== CONTEXTO DO DISPOSITIVO ===
- Nome do Paciente: $patientName
- Data/Hora Atual no Dispositivo: $deviceCurrentTime
- Alarmes Cadastrados (com índice da lista completa):
${jsonEncode(alarmsJsonList)}

- Medicamentos Cadastrados:
${jsonEncode(medicationsJsonList)}

- Lembretes Ativos para Hoje (com índice da lista ativa):
${jsonEncode(remindersJsonList)}
==============================

REGRAS IMPORTANTES DE NEGÓCIO E INTERAÇÃO:
1. Sempre responda ao paciente diretamente, educadamente e faça uma saudação amigável.
2. Quando o paciente pedir para mudar o horário de um alarme (ex: "mude o alarme das 8 para as 10:30", "quero tomar mais tarde"), você DEVE perguntar: "Essa mudança é só para hoje ou para todos os dias?". NÃO envie nenhuma ação no JSON; envie apenas a mensagem explicativa com "actions": [].
3. Se o paciente responder "só hoje" (ou usar termos semelhantes como "adiar", "atrasar", "tomar depois hoje"), retorne a ação "snooze_alarm" com os minutos de atraso calculados a partir do horário original do alarme, utilizando o índice correto do alarme.
4. Se o paciente responder "permanente" / "todos os dias" / "sempre", use a ação "update_alarm" com o novo horário utilizando o índice do alarme.
5. Se o paciente disser algo como "vou tomar às 10:30" referindo-se a um alarme que era às 08:00, e a intenção for só para hoje, calcule a diferença de minutos (150 minutos) e use snooze_alarm.
6. Sempre use o histórico da conversa para inferir sobre qual alarme, medicamento ou lembrete o paciente está falando. Se houver ambiguidade, faça perguntas de esclarecimento educadas antes de realizar qualquer ação.
7. Para a ação "mark_taken", localize o alarme correspondente na lista de alarmes. Se ele estiver tocando/ativo, a ação deve conter o índice correto.
8. Para criar ou gerenciar lembretes, use as ações correspondentes como "add_reminder" ou "complete_reminder".

FORMATO DE RESPOSTA OBRIGATÓRIO (JSON):
Você deve responder APENAS com um objeto JSON válido, sem qualquer bloco de código markdown adicional (como ```json ou ```). O formato deve ser exatamente:
{
  "message": "Sua resposta natural, empática e com saudação para o paciente.",
  "actions": [
    { "type": "mark_taken", "params": { "index": 0, "quantity": 1.0 } },
    { "type": "snooze_alarm", "params": { "index": 0, "minutes": 10 } },
    { "type": "toggle_alarm", "params": { "index": 0 } },
    { "type": "remove_alarm", "params": { "index": 0 } },
    { "type": "add_alarm", "params": { "name": "Nome do Alarme", "med_name": "Nome do Medicamento", "hour": 8, "minute": 0, "quantity": 1.0, "days": [0,1,2,3,4,5,6], "color": "blue", "type": "comprimido", "dosage": "500mg", "start_date": "2026-06-30", "duration_days": 10 } },
    { "type": "update_alarm", "params": { "index": 0, "name": "Nome", "hour": 10, "minute": 30, "quantity": 1.0, "days": [0,1,2,3,4,5,6] } },
    { "type": "add_reminder", "params": { "title": "Medir Pressão", "description": "Medir a pressão em jejum", "has_time": true, "hour": 9, "minute": 0, "period": "day", "interval": 1, "start_date": "2026-06-30", "notify_days_before": 0, "color": "red" } },
    { "type": "complete_reminder", "params": { "index": 0 } }
  ]
}

Se nenhuma ação for necessária ou se você precisar de esclarecimentos do paciente primeiro, envie a lista de "actions" vazia: "actions": []
''';

    // 3. Initialize the Gemini Model
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );

    // 4. Convert history to Content format
    final List<Content> contents = [];
    if (history != null) {
      for (final turn in history) {
        final role = turn['role'] as String? ?? 'user';
        final parts = turn['parts'] as List? ?? [];
        final List<Part> contentParts = [];
        for (final p in parts) {
          if (p is Map && p.containsKey('text')) {
            contentParts.add(TextPart(p['text'] as String));
          }
        }
        if (contentParts.isNotEmpty) {
          contents.add(Content(role, contentParts));
        }
      }
    }

    // Append the new message
    contents.add(Content.text(message));

    // 5. Generate content
    final response = await model.generateContent(contents).timeout(const Duration(seconds: 8));
    final responseText = response.text;

    if (responseText == null || responseText.isEmpty) {
      throw Exception('Received empty response from Gemini.');
    }

    // Clean JSON markdown if model wrapped it
    final cleanedResponse = responseText
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    try {
      final jsonMap = jsonDecode(cleanedResponse) as Map<String, dynamic>;
      return LlmResponse.fromJson(jsonMap, provider: 'gemini');
    } catch (e) {
      // If parsing fails, wrap the raw response as the message with empty actions
      return LlmResponse(
        message: responseText,
        actions: const [],
        provider: 'gemini',
      );
    }
  }
}
