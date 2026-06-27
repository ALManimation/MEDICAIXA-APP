# API REST — MediCaixa ESP32-S3

> Referência rápida de todos os endpoints HTTP do firmware MediCaixa.
> Base URL: `http://<IP_VIA_MDNS>` (porta 80) | Hostname: `medicaixa2.local`

---

## Alarmes

| Método | Endpoint | Payload | Descrição |
|--------|----------|---------|-----------|
| GET | `/alarms` | — | Lista todos os alarmes |
| POST | `/add` | `AlarmModel` (sem `id`) | Cria alarme (id auto-gerado) |
| POST | `/update` | `AlarmModel` completo | Atualiza alarme existente |
| POST | `/remove` | `{"id": N}` | Remove alarme |
| POST | `/toggle` | `{"id": N, "enabled": bool}` | Habilita/desabilita |
| POST | `/pause` | `{"id": N, "pause_until": epoch}` | Suspensão temporária |
| POST | `/snooze` | `{"id": N, "minutes": N}` | Adia alarme ativo |
| POST | `/mark_taken` | `{"id": N}` | Marca como tomado |
| POST | `/mark_skipped` | `{"id": N}` | Marca como não tomado |
| POST | `/take_prn` | `{"id": N}` | Registra dose sob demanda (PRN) |

## Lembretes

| Método | Endpoint | Payload | Descrição |
|--------|----------|---------|-----------|
| GET | `/api/reminders` | — | Lista lembretes |
| POST | `/api/reminders` | `ReminderModel` (sem `id`) | Cria lembrete |
| POST | `/api/reminders/update` | `ReminderModel` completo | Atualiza lembrete |
| POST | `/api/reminders/remove` | `{"id": N}` | Remove lembrete |
| POST | `/api/reminders/complete` | `{"id": N}` | Marca como concluído hoje |
| POST | `/api/reminders/toggle` | `{"id": N, "enabled": bool}` | Habilita/desabilita |

## Medicamentos

| Método | Endpoint | Payload | Descrição |
|--------|----------|---------|-----------|
| GET | `/meds_list` | — | Lista medicamentos do paciente |
| POST | `/meds_add` | `MedModel` | Adiciona medicamento |
| POST | `/meds_update` | `MedModel` | Atualiza medicamento |
| POST | `/meds_remove` | `{"name": "..."}` | Remove medicamento |

## Wi-Fi

| Método | Endpoint | Payload | Descrição |
|--------|----------|---------|-----------|
| GET | `/wifi_list` | — | Redes salvas |
| GET | `/wifi_scan` | — | Scan de redes disponíveis |
| POST | `/wifi_add` | `{"ssid":"...","password":"..."}` | Adiciona rede |
| POST | `/wifi_remove` | `{"ssid":"..."}` | Remove rede |

## Configurações

| Método | Endpoint | Payload | Descrição |
|--------|----------|---------|-----------|
| GET | `/settings` | — | Todas as configurações |
| POST | `/save_settings` | Campos parciais | Salva ajustes |
| GET | `/patient_name` | — | Nome do paciente |
| POST | `/save_patient_name` | `{"patient_name":"..."}` | Salva nome |

## Sistema

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/api/status` | Status completo (heap, uptime, settings) — **Handshake principal** |
| GET | `/voice_status` | Estado do voice client |
| GET | `/server_time` | Hora do RTC/NTP |
| POST | `/set_datetime` | Sincroniza relógio |
| GET | `/logs` | Logs do sistema |
| GET | `/history` | Histórico de tomadas |
| GET | `/context` | Contexto do LLM (debug) |
| GET | `/chat_history` | Histórico de chat |
| POST | `/chat_history/add` | Adiciona mensagem ao chat |
| POST | `/voice_input/clear` | Limpa buffer de voz |
| GET | `/check_updates` | Info de versão |

## Ações

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/restart` | Reinicia o ESP32 |
| POST | `/reset` | ⚠️ Factory reset (apaga tudo!) |
| POST | `/test_sound` | Toca som de teste |
| POST | `/api/scan_qr` | Captura QR code pela câmera |
| GET | `/api/camera_preview` | Preview JPEG da câmera |

## Backup / Restore

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/backup` | JSON completo (alarms, settings, meds, reminders, history, wifi, chat) |
| POST | `/restore` | Restaura todos os dados a partir do JSON de backup |

---

## Resposta de Sucesso Padrão

```json
{"ok": true}
```

Para criação: `{"ok": true, "id": 42}` (retorna o ID atribuído pelo ESP32).

## Resposta de Erro

```json
{"error": "Mensagem de erro"}
```
HTTP status code: `400` (bad request), `404` (not found), `500` (internal error).

---

## Exemplo: JSON de Alarme Real

```json
{
  "id": 39,
  "hour": 22,
  "minute": 0,
  "name": "Anticoncepcional",
  "med_name": "Anticoncepcional",
  "enabled": true,
  "active": true,
  "days": [true, true, true, true, true, true, true],
  "status": "PENDENTE",
  "color": "pink",
  "quantity": 1,
  "days_quantity": [0, 0, 0, 0, 0, 0, 0],
  "type": "comprimido",
  "dosage": "0.15mg",
  "last_status": null,
  "last_status_date": null,
  "snooze_min": 0,
  "created_date": "2026-06-21",
  "cycle_on_days": 21,
  "cycle_off_days": 7,
  "cycle_current_day": 4,
  "cycle_is_paused": false
}
```

## Exemplo: JSON de Lembrete Real

```json
{
  "id": 1,
  "title": "Consulta",
  "description": "Dr. Maurício",
  "enabled": true,
  "has_time": false,
  "period": "",
  "interval": 0,
  "start_date": "2026-06-15",
  "notify_days_before": 3,
  "last_completed_date": "20/06/2026",
  "color": "purple"
}
```

## Exemplo: JSON de Settings Real

```json
{
  "alarm_sound": 0,
  "alarm_spacing_ms": 10000,
  "patient_name": "Carolina",
  "wake_word": "jarvis",
  "brightness": 5,
  "speaker_volume": 10,
  "language": "pt",
  "sleep_time": "23:00",
  "wake_time": "06:00",
  "sleep_schedule_enabled": true,
  "alarm_wizard_enabled": true,
  "breakfast_time": "08:00",
  "lunch_time": "12:00",
  "dinner_time": "20:00",
  "prohibited_ranges": [
    {"from": "11:30", "to": "13:00"},
    {"from": "17:30", "to": "18:45"}
  ]
}
```
