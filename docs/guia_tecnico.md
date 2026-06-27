# Guia Técnico de Programação — App MediCaixa Flutter

> **Versão**: 2.1 — Atualizado em 26/06/2026
> **Objetivo**: Orientar um agente de IA (Antigravity 2.0 ou equivalente) no desenvolvimento do aplicativo **multiplataforma** oficial da MediCaixa usando Flutter.
> **Plataformas-alvo**: iOS, Android, macOS (desktop)
> **Firmware de referência**: `v0.90-cpp` (ESP32-S3, ESP-IDF v5.4)

---

## 1. Contexto do Projeto

A **MediCaixa** é um dispensador inteligente de medicamentos baseado em ESP32-S3. Ele possui:
- Display OLED SSD1306 para status e alertas
- Alto-falante MAX98357A + Microfone INMP441 para assistente de voz (Xiaozhi/Gemini)
- Câmera OV5640 para QR Code e fotos
- LED WS2812B para feedback visual
- Sensor Reed Switch para detecção de abertura da tampa
- RTC DS3231 para relógio offline
- Web Server HTTP local para controle via browser/app

### 1.1 O que é o Antigravity 2.0?

O **Antigravity 2.0** é a plataforma de desenvolvimento agentic da Google para Flutter. Ele **NÃO** é um SDK que se importa no app — é o ambiente de desenvolvimento que você (agente) usa para programar. Principais recursos:
- **Antigravity IDE**: Editor com painel de agente integrado
- **Antigravity CLI (`agy`)**: Interface de terminal com MCP server para Dart/Flutter
- **Agentic Hot Reload**: O agente pode sugerir e aplicar mudanças com hot reload automático
- **AGENTS.md**: Arquivo de regras que o agente lê automaticamente a cada sessão

### 1.2 App Autônomo + Sincronização com MediCaixa

O app é um **produto autônomo e independente** que funciona 100% sem a caixinha física. Quando a MediCaixa está disponível na mesma rede Wi-Fi, o app sincroniza dados automaticamente via REST/mDNS.

**Modos de operação:**
1. **Standalone (sem caixinha)**: O app gerencia alarmes, lembretes e medicamentos localmente no celular/Mac. Útil para usuários que ainda não possuem o hardware.
2. **Conectado (com caixinha)**: O app se sincroniza com a MediCaixa via rede local. O dispositivo é a **fonte da verdade** quando conectado.

```
┌──────────────────────────────────────────────────────────────────────┐
│                    App Flutter Multiplataforma                       │
│              (iOS · Android · macOS Desktop)                         │
│                                                                      │
│  • Banco local SQLite (fonte da verdade offline)                     │
│  • Motor de sincronização bidirecional                               │
│  • Busca ANVISA local instantânea                                    │
│  • Notificações locais de alarmes                                    │
│  • Funciona 100% sem a caixinha                                      │
└──────────────────────┬───────────────────────────────────────────────┘
                       │ HTTP REST (mDNS) — Wi-Fi Local
                       │ (quando disponível)
                       ▼
              ┌──────────────────┐
              │   MediCaixa      │
              │   (ESP32-S3)     │
              │                  │
              │ • AlarmManager   │
              │ • ReminderMgr    │
              │ • VoiceClient    │
              │ • WebServer      │
              └──────────────────┘
```

---

## 2. Estrutura do Projeto Flutter (Feature-First)

```
lib/
├── core/
│   ├── constants/         ← Cores, strings, configs globais
│   ├── network/           ← Cliente HTTP (Dio), discovery mDNS, interceptors
│   ├── database/          ← Drift (SQLite) ou Hive para persistência local
│   ├── security/          ← Armazenamento seguro de tokens (PIN pairing)
│   ├── theme/             ← Tema global Material 3, tipografia, paleta de cores
│   └── utils/             ← Helpers de formatação, data, validação
├── features/
│   ├── pairing/           ← Descoberta mDNS + emparelhamento PIN
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── alarms/            ← CRUD completo de alarmes de medicamentos
│   │   ├── data/          ← AlarmRepository, API client, modelos JSON
│   │   ├── domain/        ← Alarm entity, interfaces de repositório
│   │   └── presentation/  ← Telas, widgets, notifiers/controllers
│   ├── reminders/         ← Lembretes (consultas, exames, tarefas)
│   ├── medications/       ← Busca ANVISA local com fuzzy matching
│   ├── history/           ← Histórico de eventos (tomadas, perdidas)
│   ├── settings/          ← Configurações do app + comandos da caixinha
│   └── dashboard/         ← Tela inicial com resumo do dia
├── app.dart               ← MaterialApp, rotas, providers globais
└── main.dart              ← Entry point
```

## 3. Dependências Recomendadas (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Gerência de Estado (Riverpod 2.x — recomendado para 2026)
  flutter_riverpod: ^2.6.0
  riverpod_annotation: ^2.4.0

  # Banco de Dados Local (Drift = SQLite type-safe com streams reativos)
  drift: ^2.22.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.9.0

  # Comunicação de Rede
  dio: ^5.7.0
  multicast_dns: ^0.3.2+1    # Discovery mDNS multiplataforma

  # Segurança
  flutter_secure_storage: ^9.2.0
  crypto: ^3.0.6

  # UI e Design
  google_fonts: ^6.2.0
  flutter_local_notifications: ^18.0.0
  intl: ^0.19.0

  # Utilidades
  uuid: ^4.5.0
  connectivity_plus: ^6.1.0   # Monitor de conectividade
  workmanager: ^0.5.2         # Background sync tasks

dev_dependencies:
  drift_dev: ^2.22.0
  build_runner: ^2.4.0
  riverpod_generator: ^2.4.0
```

> **Nota sobre Hive vs Drift**: Para dados médicos estruturados com relações (alarmes ↔ histórico), **Drift (SQLite)** é mais robusto que Hive. Drift suporta queries complexas, migrações, e streams reativos nativos.

---

## 4. Modelos de Dados Dart

Estes modelos espelham **exatamente** as structs C++ do firmware. A API REST retorna JSONs com estes campos.

### 4.1 Modelo de Alarme

```dart
/// Espelha a struct Alarm do firmware (alarm_manager.h)
/// Campos opcionais avançados só aparecem no JSON quando estão ativos.
class AlarmModel {
  final int id;
  final int hour;
  final int minute;
  final String name;
  final String medName;        // "med_name" no JSON
  final bool enabled;
  final bool active;           // Se está ativo (enabled + não suspenso + dentro da data)
  final List<bool> days;       // 7 bools [Dom, Seg, Ter, Qua, Qui, Sex, Sab]
  final String status;         // "PENDENTE", "TOMANDO", "SNOOZED"
  final String color;          // "red", "blue", "magenta", "pink", etc.
  final double quantity;       // Suporta frações: 0.5, 1, 1.5
  final List<double> daysQuantity; // 7 doubles — quantidade por dia (0 = usar quantity padrão)
  final String type;           // "comprimido", "capsula", "gota", "dose"
  final String? dosage;        // "40mg", "10ml", "0.15mg"
  final String? lastStatus;    // "Tomado", "Não Tomado", "Perdido", null
  final String? lastStatusDate;// "DD/MM/YYYY" ou null
  final int snoozeMin;         // Tempo de snooze em minutos (0 = nenhum)
  final String? startDate;     // "YYYY-MM-DD" — data de início (null = recorrente por dias)
  final int durationDays;      // Duração em dias (0 = recorrente)
  final String? createdDate;   // "YYYY-MM-DD"

  // --- Campos Avançados (opcionais no JSON) ---
  // Ciclo (ex: anticoncepcional 21+7)
  final int? cycleOnDays;      // Dias de uso ativo (null/0 = sem ciclo)
  final int? cycleOffDays;     // Dias de pausa
  final int? cycleCurrentDay;  // Dia atual no ciclo
  final bool? cycleIsPaused;   // true = fase de pausa

  // PRN / Sob Demanda
  final bool? isPrn;
  final int? prnMinIntervalHours;
  final int? prnMaxDailyDoses;
  final int? prnDosesToday;

  // Suspensão Temporária
  final int? pauseUntil;       // Epoch (0 = ativo, -1 = indefinido, >0 = data)

  // Escala Móvel / Dose Dinâmica
  final bool? isDynamic;
  final String? dynamicInstruction;

  // Desmame/Titulação (Taper)
  final int? taperStageCount;
  final int? taperCurrentStage;
  final int? taperDayInStage;
  final List<TaperStage>? taperStages;
  final bool? taperLoop;

  // Instrução Especial
  final String? specialInstruction; // "empty_stomach", "with_food", "sublingual"

  // Ajuste Progressivo
  final double? adjustStep;
  final int? adjustIntervalDays;
  final double? adjustLimit;

  // Rodízio de locais (adesivos/injeções)
  final bool? requiresRemoval;
  final int? removalDelayMins;
  final String? siteRotationList;
  final int? currentSiteIndex;

  // Dia fixo do mês
  final int? dayOfMonth;       // 1-31, 0 = inativo

  // Grupo / Intervalo
  final int? groupId;
  final int? intervalHours;

  // Sync control (app-only, não enviado ao ESP32)
  final int? lastModified;
  final bool pendingSync;

  // ... constructor, fromJson, toJson ...
}

class TaperStage {
  final double quantity;
  final int durationDays;
  // ... constructor, fromJson, toJson ...
}
```

### 4.2 Modelo de Lembrete

```dart
/// Espelha a struct Reminder do firmware (reminder_manager.h)
class ReminderModel {
  final int id;
  final String title;
  final String description;
  final bool enabled;
  final bool hasTime;          // Se tem hora específica
  final int? hour;             // Só se hasTime=true
  final int? minute;           // Só se hasTime=true
  final String period;         // "day", "week", "month", "year", "" (uma vez)
  final int interval;          // A cada N períodos (0 = uma vez)
  final String startDate;      // "YYYY-MM-DD"
  final int notifyDaysBefore;  // 0-7 dias antes
  final String? lastCompletedDate; // "DD/MM/YYYY" ou null
  final String color;          // "purple", "orange", "blue"

  // Sync control (app-only)
  final int? lastModified;
  final bool pendingSync;

  // ... constructor, fromJson, toJson ...
}
```

### 4.3 Modelo de Settings

```dart
class SettingsModel {
  final String patientName;
  final int speakerVolume;     // 0-100
  final int brightness;        // 0-100
  final String language;       // "pt", "en", "es"
  final String wakeWord;       // "jarvis", "hey_kira", "sofia", "hey_wanda"
  final int alarmSound;        // 0-N
  final int alarmSpacingMs;    // Intervalo entre alarmes simultâneos
  final bool alarmWizardEnabled;
  final String? sleepTime;     // "HH:MM" ou null
  final String? wakeTime;      // "HH:MM" ou null
  final bool sleepScheduleEnabled;
  final String? breakfastTime; // "HH:MM"
  final String? lunchTime;     // "HH:MM"
  final String? dinnerTime;    // "HH:MM"
  final String? geminiApiKey;
  final List<TimeRange>? prohibitedRanges; // Intervalos proibidos

  // ... constructor, fromJson, toJson ...
}

class TimeRange {
  final String from; // "HH:MM"
  final String to;   // "HH:MM"
}
```

---

## 5. Mapeamento Completo da API REST

Base URL: `http://<IP_DESCOBERTO_VIA_MDNS>` (porta 80). O hostname mDNS é `medicaixa2.local`.

### 5.1 Alarmes

| Método | Endpoint | Payload | Resposta | Descrição |
|--------|----------|---------|----------|-----------|
| GET | `/alarms` | — | `AlarmModel[]` | Lista todos os alarmes |
| POST | `/add` | `AlarmModel` (sem `id`) | `{"ok":true,"id":N}` | Cria alarme (id auto-gerado) |
| POST | `/update` | `AlarmModel` completo | `{"ok":true}` | Atualiza alarme existente |
| POST | `/remove` | `{"id": N}` | `{"ok":true}` | Remove alarme |
| POST | `/toggle` | `{"id": N, "enabled": bool}` | `{"ok":true}` | Habilita/desabilita |
| POST | `/pause` | `{"id": N, "pause_until": epoch}` | `{"ok":true}` | Suspensão temporária |
| POST | `/snooze` | `{"id": N, "minutes": N}` | `{"ok":true}` | Adia alarme ativo |
| POST | `/mark_taken` | `{"id": N}` | `{"ok":true}` | Marca como tomado |
| POST | `/mark_skipped` | `{"id": N}` | `{"ok":true}` | Marca como não tomado |
| POST | `/take_prn` | `{"id": N}` | `{"ok":true}` | Registra dose sob demanda |

### 5.2 Lembretes

| Método | Endpoint | Payload | Resposta | Descrição |
|--------|----------|---------|----------|-----------|
| GET | `/api/reminders` | — | `ReminderModel[]` | Lista lembretes |
| POST | `/api/reminders` | `ReminderModel` (sem `id`) | `{"ok":true,"id":N}` | Cria lembrete |
| POST | `/api/reminders/update` | `ReminderModel` completo | `{"ok":true}` | Atualiza lembrete |
| POST | `/api/reminders/remove` | `{"id": N}` | `{"ok":true}` | Remove lembrete |
| POST | `/api/reminders/complete` | `{"id": N}` | `{"ok":true}` | Marca como concluído hoje |
| POST | `/api/reminders/toggle` | `{"id": N, "enabled": bool}` | `{"ok":true}` | Habilita/desabilita |

### 5.3 Medicamentos Cadastrados

| Método | Endpoint | Payload | Resposta | Descrição |
|--------|----------|---------|----------|-----------|
| GET | `/meds_list` | — | `MedModel[]` | Lista medicamentos do paciente |
| POST | `/meds_add` | `MedModel` | `{"ok":true}` | Adiciona medicamento |
| POST | `/meds_update` | `MedModel` | `{"ok":true}` | Atualiza medicamento |
| POST | `/meds_remove` | `{"name": "..."}` | `{"ok":true}` | Remove medicamento |

### 5.4 Wi-Fi

| Método | Endpoint | Payload | Resposta | Descrição |
|--------|----------|---------|----------|-----------|
| GET | `/wifi_list` | — | `WifiEntry[]` | Redes salvas |
| GET | `/wifi_scan` | — | `ScanResult[]` | Scan de redes disponíveis |
| POST | `/wifi_add` | `{"ssid":"...","password":"..."}` | `{"ok":true}` | Adiciona rede |
| POST | `/wifi_remove` | `{"ssid":"..."}` | `{"ok":true}` | Remove rede |

### 5.5 Configurações e Paciente

| Método | Endpoint | Payload | Resposta | Descrição |
|--------|----------|---------|----------|-----------|
| GET | `/settings` | — | `SettingsModel` | Todas as configurações |
| POST | `/save_settings` | `SettingsModel` parcial | `{"ok":true}` | Salva ajustes |
| GET | `/patient_name` | — | `{"patient_name":"..."}` | Nome do paciente |
| POST | `/save_patient_name` | `{"patient_name":"..."}` | `{"ok":true}` | Salva nome |

### 5.6 Sistema, Tempo e Logs

| Método | Endpoint | Resposta | Descrição |
|--------|----------|----------|-----------|
| GET | `/api/status` | Status completo (heap, uptime, settings) | Handshake principal |
| GET | `/voice_status` | Estado do voice client | Status da conexão de voz |
| GET | `/server_time` | `{"epoch":N,"datetime":"..."}` | Hora do RTC/NTP |
| POST | `/set_datetime` | `{"epoch": N}` | Sincroniza relógio |
| GET | `/logs` | Array de log entries | Logs do sistema |
| GET | `/history` | Array de eventos | Histórico de tomadas |
| GET | `/context` | Contexto completo do LLM | Debug: contexto de voz |
| GET | `/chat_history` | Array de mensagens | Histórico de chat |
| POST | `/chat_history/add` | `{"role":"...","content":"..."}` | Adiciona mensagem ao chat |
| POST | `/voice_input/clear` | — | Limpa buffer de voz |
| GET | `/check_updates` | Info de versão | Verificar atualizações |

### 5.7 Ações do Dispositivo

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/restart` | Reinicia o ESP32 |
| POST | `/reset` | Factory reset (apaga dados!) |
| POST | `/test_sound` | Toca som de teste |
| POST | `/api/scan_qr` | Captura QR code pela câmera |
| GET | `/api/camera_preview` | Preview JPEG da câmera |

### 5.8 Backup e Restore

| Método | Endpoint | Payload | Descrição |
|--------|----------|---------|-----------|
| GET | `/backup` | — | Retorna JSON completo com todos os dados |
| POST | `/restore` | JSON de backup completo | Restaura todos os dados |

> **⚠️ Importante**: O endpoint `/backup` retorna um JSON com as chaves: `settings`, `alarms`, `meds`, `wifi`, `xiaozhi`, `logs`, `chat_history`, `reminders`, `history`, `backup_date`, `firmware_version`. Este é o endpoint ideal para sincronização completa inicial.

---

## 6. Descoberta do Dispositivo via mDNS

A MediCaixa anuncia o hostname `medicaixa2.local` via mDNS na porta 80.

### 6.1 Configuração por Plataforma

**iOS** — Adicionar ao `ios/Runner/Info.plist`:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>MediCaixa precisa acessar a rede local para se conectar ao seu dispensador.</string>
<key>NSBonjourServices</key>
<array>
  <string>_http._tcp</string>
</array>
```

**Android** — Adicionar ao `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
```

**macOS** — Adicionar ao `macos/Runner/DebugProfile.entitlements` e `Release.entitlements`:
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```
> **Nota macOS**: O Bonjour/mDNS funciona nativamente no macOS sem configuração adicional. Apenas os entitlements de rede são necessários para que o app sandboxed consiga acessar a rede local.

### 6.2 Exemplo de Discovery com `multicast_dns`

```dart
import 'package:multicast_dns/multicast_dns.dart';

Future<String?> discoverMediCaixa() async {
  final client = MDnsClient();
  await client.start();

  String? deviceIp;

  // Buscar SRV record para medicaixa2.local
  await for (final ptr in client.lookup<PtrResourceRecord>(
    ResourceRecordQuery.serverPointer('_http._tcp'))) {

    await for (final srv in client.lookup<SrvResourceRecord>(
      ResourceRecordQuery.service(ptr.domainName))) {

      if (srv.target.toLowerCase().contains('medicaixa')) {
        await for (final ip in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target))) {
          deviceIp = ip.address.address;
        }
      }
    }
  }

  client.stop();
  return deviceIp != null ? 'http://$deviceIp' : null;
}
```

### 6.3 Fallback: IP Direto

Se o mDNS falhar (comum em redes corporativas), permitir que o usuário insira o IP manualmente:
```
http://192.168.x.x
```

---

## 7. Motor de Sincronização Offline-First

### 7.1 Princípio: Local-First

O app **sempre lê do banco local**. A rede é usada apenas para sincronizar com o dispositivo.

```
UI ← lê ← Banco Local (Drift/SQLite)
                ↑ atualiza ↑
           Sync Engine
                ↑ HTTP ↑
          MediCaixa (ESP32)
```

### 7.2 Algoritmo de Sincronização

```
[App conecta ao dispositivo]
        │
        ▼
Chama GET /api/status → obtém last_modified do dispositivo
        │
        ▼
Lê last_sync_timestamp do banco local
        │
        ├─► CASO 1: Primeira conexão (sem dados locais)
        │     1. Chama GET /backup (download completo)
        │     2. Popula banco local com todos os dados
        │     3. Salva last_sync_timestamp = agora
        │
        ├─► CASO 2: local == dispositivo (nada mudou)
        │     Sem ação. Baixar histórico incremental se necessário.
        │
        ├─► CASO 3: local < dispositivo (alterações via voz/botão)
        │     1. GET /alarms + GET /api/reminders + GET /settings
        │     2. Merge: sobrescrever banco local com dados da caixinha
        │     3. Atualizar last_sync_timestamp
        │
        └─► CASO 4: local > dispositivo (alarmes criados offline no app)
              1. Filtrar registros com pendingSync == true
              2. Enviar via POST /add ou POST /update
              3. Marcar pendingSync = false
              4. Atualizar last_sync_timestamp
```

### 7.3 Resolução de Conflitos

Quando `local != dispositivo` e existem pendingSync locais:
1. **Dispositivo vence** para alarmes existentes (o paciente pode ter tomado/adiado via voz)
2. **App vence** para alarmes novos (id local temporário, o ESP32 atribui o id real)
3. Após o push, fazer GET /alarms para obter os IDs definitivos

---

## 8. Banco de Medicamentos ANVISA (Fuzzy Search Local)

O ESP32 gasta 2-4s rodando Levenshtein na CPU. O Flutter deve assumir essa busca **localmente e instantaneamente**.

### 8.1 Estratégia

1. **Incluir** o arquivo `medications_db.json.gz` (~200KB comprimido) na pasta `assets/` do app
2. **Carregar** em um `Isolate` dedicado na inicialização (não bloqueia a UI)
3. **Buscar** com 3 tiers progressivos:

```dart
List<MedEntry> searchMedications(String query, List<MedEntry> db) {
  final q = query.toLowerCase().trim();
  if (q.length < 2) return [];

  // Tier 1: Prefixo exato (mais rápido)
  var results = db.where((m) => m.name.toLowerCase().startsWith(q)).toList();
  if (results.length >= 5) return results.take(20).toList();

  // Tier 2: Substring (contém)
  results = db.where((m) => m.name.toLowerCase().contains(q)).toList();
  if (results.length >= 3) return results.take(20).toList();

  // Tier 3: Levenshtein Fuzzy (tolerância a erros de digitação)
  results = db
    .map((m) => MapEntry(m, levenshteinDistance(q, m.name.toLowerCase())))
    .where((e) => e.value <= 3)  // max 3 edits
    .toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return results.map((e) => e.key).take(20).toList();
}
```

---

## 9. Segurança e Pairing (Fase 2)

> **Nota**: O pairing via PIN é uma funcionalidade de **Fase 2**. Na Fase 1, o app se conecta diretamente sem autenticação.

### 9.1 Fluxo de Emparelhamento

```
1. App abre tela "Adicionar Caixinha"
2. App descobre via mDNS ou usuário insere IP
3. MediCaixa exibe PIN de 6 dígitos no OLED
4. Usuário digita o PIN no app
5. App envia POST /api/pair { "pin_hash": sha256(PIN + salt) }
6. ESP32 valida e retorna { "token": "xxx..." }
7. App salva token no FlutterSecureStorage
8. Todas as chamadas futuras incluem: Authorization: Bearer <token>
```

### 9.2 Armazenamento Seguro

```dart
final storage = FlutterSecureStorage();
await storage.write(key: 'medicaixa_token', value: token);

// Nos interceptors do Dio:
final token = await storage.read(key: 'medicaixa_token');
if (token != null) {
  options.headers['Authorization'] = 'Bearer $token';
}
```

---

## 10. Diretrizes de UX e Design

### 10.1 Paleta de Cores dos Alarmes

O firmware usa estas cores nos alarmes. O app deve mapeá-las identicamente:

| Cor no JSON | Hex Sugerido | Uso Típico |
|-------------|-------------|------------|
| `"red"` | `#E53935` | Urgente/Importante |
| `"blue"` | `#1E88E5` | Padrão |
| `"green"` | `#43A047` | Vitaminas/Suplementos |
| `"yellow"` | `#FDD835` | Atenção |
| `"orange"` | `#FB8C00` | Alerta moderado |
| `"purple"` | `#8E24AA` | Psiquiátricos |
| `"pink"` | `#EC407A` | Hormônios |
| `"magenta"` | `#D81B60` | Cardiovascular |
| `"cyan"` | `#00ACC1` | Anti-inflamatórios |
| `"brown"` | `#6D4C41` | Outros |

### 10.2 Badges de Status

- **Ciclo ativo**: Badge mostrando "Dia X de Y" (ex: "Dia 4 de 21")
- **PRN (Sob Demanda)**: Badge "SOS" ou "Sob Demanda"
- **Dose Dinâmica**: Badge "Escala Móvel"
- **Suspenso**: Card com opacidade reduzida e badge "Pausado"
- **Desmame/Titulação**: Badge "Etapa X de Y"

### 10.3 Tema Visual

O app deve seguir Material 3 com tema escuro premium:
- Usar `google_fonts` (Inter ou Roboto para body, Outfit para headings)
- Gradientes sutis nos cards
- Micro-animações de transição entre telas
- Modo escuro como padrão (pacientes usam à noite)

---

## 11. Template AGENTS.md para o Projeto Flutter

Criar um arquivo `.agents/AGENTS.md` na raiz do projeto Flutter com estas regras:

```markdown
# AGENTS.md — MediCaixa App Flutter

## Stack
- Flutter 3.x + Dart 3.x
- State Management: Riverpod 2.x (com code generation)
- Local DB: Drift (SQLite) com streams reativos
- HTTP Client: Dio 5.x com interceptors
- Architecture: Feature-First Clean Architecture

## Regras Obrigatórias
1. **Offline-First**: A UI SEMPRE lê do banco local. Nunca faça chamadas HTTP diretas na camada de apresentação.
2. **Repository Pattern**: Toda comunicação com o dispositivo passa pelo Repository, que decide se lê do cache ou da rede.
3. **AsyncValue**: Use `AsyncValue` do Riverpod para todos os estados assíncronos. Nunca use flags manuais `isLoading`.
4. **Isolates para CPU-heavy**: Busca ANVISA e parsing de JSON grande devem rodar em Isolates dedicados.
5. **Tratamento de Erros**: Todo try/catch deve retornar mensagens estruturadas ao usuário, nunca falhar silenciosamente.
6. **Timeouts**: Toda requisição HTTP deve ter timeout de 5 segundos (o ESP32 é local, respostas são rápidas).
7. **Nomes de Campos JSON**: Usar snake_case nos JSONs (ex: `med_name`, `last_status_date`) para compatibilidade com o firmware.

## Arquivos Proibidos de Editar
- `assets/medications_db.json.gz` (gerado externamente)
- Arquivos em `build/` e `.dart_tool/`

## Comandos
- Build: `flutter build apk` ou `flutter build ios`
- Test: `flutter test`
- Code gen: `dart run build_runner build --delete-conflicting-outputs`
- Dev: `flutter run`
```

---

## 12. Gotchas Técnicos e Armadilhas

### 12.1 Campos JSON do ESP32

| Armadilha | Solução |
|-----------|---------|
| `quantity` vem como `int` quando inteiro, `float` quando fracionado | Sempre parsear como `double`: `(json['quantity'] as num).toDouble()` |
| `days` é array de 7 bools, indexado por [Dom=0, Seg=1, ..., Sab=6] | Manter mesma indexação no Dart, converter para labels localizados na UI |
| `last_status` e `last_status_date` podem ser `null` | Usar `String?` nullable |
| `start_date` vem como `"YYYY-MM-DD"` string | Parsear com `DateTime.parse()` |
| Campos avançados (cycle, prn, taper) **não existem** no JSON se inativos | Usar `json.containsKey()` ou defaults no `fromJson` |
| `id` é `uint8_t` no firmware (0-255) | Limitar range no app, IDs temporários locais devem ser > 255 |

### 12.2 Limitações do ESP32

| Limitação | Impacto no App |
|-----------|---------------|
| DRAM limitada (~270KB) | Não fazer muitas requisições simultâneas; serializar chamadas HTTP |
| Sem HTTPS/TLS local | Comunicação é HTTP puro na rede local (OK para LAN privada) |
| Sem WebSocket para push | O app precisa fazer polling ou sincronizar no foreground |
| Processamento lento de JSON grande | Evitar enviar JSONs > 4KB em um único POST |

### 12.3 mDNS em Android

- Emuladores Android **não suportam** mDNS — testar sempre em dispositivo físico
- Alguns roteadores bloqueiam multicast — sempre oferecer fallback de IP manual
- Em Android 12+, declarar permissão `NEARBY_WIFI_DEVICES` se targeting API 33+

### 12.4 Considerações macOS Desktop

- O app deve ter layout responsivo: em telas grandes (macOS), usar layout de 2 colunas (sidebar + content)
- `flutter_local_notifications` tem suporte limitado no macOS — verificar compatibilidade ou usar `macos_ui` para notificações nativas
- O macOS sandbox exige entitlements explícitos para acesso à rede local (já documentado na seção 6.1)
- Testar com `flutter run -d macos` — o hot reload funciona normalmente
- Atalhos de teclado: considerar `Cmd+N` para novo alarme, `Cmd+S` para sincronizar, etc.
- Tamanho mínimo de janela recomendado: 800x600px

---

## 13. Checklist de Validação

### Primeira Versão (MVP)
- [ ] Descoberta mDNS funciona em iOS e Android físico
- [ ] Fallback de IP manual funciona
- [ ] Listar alarmes do dispositivo com todos os campos renderizados
- [ ] Criar alarme básico e enviar ao ESP32
- [ ] Dashboard mostra resumo do dia (pendentes, tomados, perdidos)
- [ ] Funciona 100% offline com dados locais
- [ ] Sincroniza ao reconectar com a caixinha
- [ ] Busca de medicamentos ANVISA funciona instantaneamente
- [ ] Cards mostram badges corretas (ciclo, PRN, dinâmico, suspenso)

### Fase 2
- [ ] Pairing via PIN com armazenamento seguro
- [ ] Notificações locais de alarmes
- [ ] Histórico de tomadas com filtros
- [ ] Configurações do dispositivo (volume, brilho, wake word)
- [ ] Backup/Restore completo via app

