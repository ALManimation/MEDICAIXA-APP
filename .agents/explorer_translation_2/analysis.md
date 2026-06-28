# Translation Mapping and Completeness Analysis for MediCaixa App

## 1. Summary of Findings
- **Existing Alignment**: The existing local translation files (`assets/lang/pt.json`, `assets/lang/en.json`, and `assets/lang/es.json`) are perfectly synchronized. Each file has exactly **606 keys** with identical structures and no mismatched, missing, or stray keys.
- **Hardcoded Strings**: While the JSON files are aligned, the Flutter app has a significant number of hardcoded user-facing strings in Portuguese in its Dart code (e.g., in Dashboard, Medications, Reports, Settings, active alarm screens, and modal dialogs).
- **R1 Localization Path**: To achieve 100% localization coverage for the R1 milestone, new translation keys must be added to all three JSON files, and references in the code must be updated to use the `t()` helper defined in `app_localizations.dart`.

---

## 2. Completeness and File Mapping
An automated audit of the JSON files in the workspace reveals the following metrics:

| Translation File Path | Total Keys | Synchronization Status | Mismatches Found |
| :--- | :---: | :---: | :---: |
| `assets/lang/pt.json` | 606 | **100% Synced** | None |
| `assets/lang/en.json` | 606 | **100% Synced** | None |
| `assets/lang/es.json` | 606 | **100% Synced** | None |
| `docs/reference/pt.json` | 606 | **100% Synced** | None |
| `docs/reference/en.json` | 606 | **100% Synced** | None |
| `docs/reference/es.json` | 606 | **100% Synced** | None |

*Note: There are no key discrepancies (e.g., `PT - EN`, `EN - PT`, `PT - ES` are all empty sets).*

---

## 3. Identified Code Localization Gaps (Hardcoded Portuguese Text)
The following major user-facing strings are hardcoded in the codebase and should be refactored using the proposed translation keys below:

### App Shell & Navigation (`app_shell.dart`)
- `"Leitura de QR Code via câmera disponível em breve! 📸"`

### Dashboard (`dashboard_screen.dart` & widgets)
- `"Desconectar"`, `"Sincronizar"`, `"Histórico & Logs"`
- `"MediCaixa conectada"`, `"Modo Offline"`
- `"perdido"`, `"perdidos"`, `"REGISTRAR"`

### Medications (`medications_list_screen.dart` & `medication_form_screen.dart`)
- `"Pesquisar medicamentos..."`, `"Nenhum medicamento correspondente."`, `"Nenhum medicamento cadastrado."`
- `"Limpar Seleção"`, `"Confirmar Exclusão"`, `"Não é possível excluir"`
- `"Não é possível excluir medicamentos em uso por alarmes:\n\n...\n\nExclua os alarmes primeiro."`
- `"Medicamentos excluídos com sucesso!"`
- `"O nome é obrigatório"`
- `"Forma de Apresentação (Tipo)"` (Dropdown label)
- Drodown values: `"Comprimido"`, `"Cápsula"`, `"Gotas"`, `"Xarope"`, `"Inalador"`, `"Injetável"`, `"Pomada"`, `"Outro"`
- `"Identificação Visual (Cor)"`
- `"SALVAR ALTERAÇÕES"`, `"CADASTRAR"`

### Reports (`reports_screen.dart` & widgets)
- `"Relatórios de Adesão"`, `"Adesão Geral (7 dias)"`, `"Adesão Diária (7 dias)"`, `"Sequência (30 dias)"`
- `"Distribuição por Período (7 dias)"`, `"Desempenho por Medicamento (7 dias)"`, `"Calendário de Adesão (30 dias)"`
- Heatmap headers: `"D"`, `"S"`, `"T"`, `"Q"`, `"Q"`, `"S"`, `"S"`
- Heatmap tooltips/legends: `"Futuro"`, `"alarmes"`, `"Sem dados"`, `"Nenhum dado por medicamento."`

### Settings (`settings_screen.dart`)
- `"Ajustes Locais"`, `"Cronograma de Sono"`, `"Dormir"`, `"Acordar"`
- `"Horários das Refeições"`, `"Café da Manhã"`, `"Almoço"`, `"Jantar"`
- `"Balizam os atalhos \"Antes do café\", \"Depois do almoço\", etc. no alarme."`
- `"Ajustes da Caixinha"`, `"Conectado via rede local"`, `"Modo Standalone (Desconectado)"`
- `"Endereço IP: ...\nFirmware: ..."`
- `"O app está salvando tudo localmente no SQLite."`
- `"Alterar Caixinha / Parear"`, `"Conectar com MediCaixa"`
- `"Configurações da Caixinha Bloqueadas"`
- `"Para alterar as configurações físicas da caixinha (...), você precisa se conectar..."`
- `"Conectar Agora"`
- `"Rede Wi-Fi da Caixinha"`, `"Gerencie as conexões de rede do dispositivo"`
- `"Sons e Tela"`
- `"Relógio sincronizado com o celular!"`
- `"Rede Wi-Fi salva com sucesso!"`
- `"Rede removida com sucesso!"`
- `"Opções de Desenvolvedor"`, `"Testes Offline (Fixture)"`
- `"Backup de teste carregado com 25 alarmes, 6 lembretes e medicamentos! 🎉"`

### Active Alarm Screen & Snooze Modal (`alarm_active_screen.dart`, `snooze_modal.dart`)
- `"HORA DO MEDICAMENTO"`, `"MARCAR COMO TOMADO"`, `"ADIAR 10 MIN"`, `"PULAR DOSE"`
- `"Aplicar em: ..."`
- `"Tomei"`, `"Pular"`, `"Dose a tomar: "`
- `"Medicamento com Dose Dinâmica (Glicose / Insulina)"`
- `"Adiar por:"`, `"minutos"`
- `"Excluir Alarme"`, `"Tem certeza que deseja excluir \"%s\"?"`, `"Cancelar"`, `"Excluir"`

### Pairing Screen (`pairing_screen.dart`)
- `"Buscar Dispositivos"`, `"Buscando MediCaixa na rede..."`, `"Nenhuma MediCaixa encontrada"`
- `"Certifique-se de que a MediCaixa está ligada e na mesma rede Wi-Fi."`
- `"Como conectar a primeira vez?"`
- `"Conectar pelo IP"`, `"Insira o IP exibido na tela da MediCaixa:"`
- `"Digite o IP da caixinha (Ex: 192.168.1.100)"`
- `"Conectar via IP"`, `"OU INSERIR IP MANUAL"`
- `"Usar sem caixinha (Modo Offline)"`, `"O aplicativo funcionará com banco de dados local."`
- `"Conectando..."`, `"Conectado!"`, `"Erro ao conectar"`

### Alarm Wizard Steps (`wizard/` folder)
- `"Qual medicamento deseja agendar?"`, `"+ Novo Medicamento"`
- `"Qual o horário e dias da semana?"`, `"Tomar na rotina diária"`, `"Tem dia e hora certos para tomar"`, `"Só de vez em quando (Sob demanda)"`
- `"Tem que esperar quantas horas antes de repetir a dose?"`
- `"Qual o máximo de vezes que pode tomar no mesmo dia?"`
- `"Qual a quantidade que você toma por vez?"`
- `"Quantidade Fixa"`, `"Sempre a mesma quantidade"`, `"Dose dinâmica"`, `"Se estiver"`, `"Qual aparelho de teste você vai usar?"`
- `"Desmame progressivo"`, `"Doses que diminuem com o tempo"`, `"Repetir esse ciclo de doses infinitamente?"`
- `"Selecione os dias da semana:"`, `"Todos os dias"`, `"Sem faltar nenhum dia"`, `"Personalizado"`, `"Escolher os dias"`, `"Mensal (Dia fixo)"`, `"Sempre no mesmo dia do mês"`, `"Uso com Pausa (Ciclo)"`, `"Tomo por X dias e folgo Y dias"`
- `"Que horas vai ser o seu PRIMEIRO remédio de hoje?"`
- `"Por quantos dias o médico mandou tomar?"`, `"Uso contínuo (Para sempre)"`, `"Tratamento com prazo definido"`, `"O médico passou por alguns dias (Ex: Antibiótico)"`
- `"RESUMO DO REMÉDIO"`, `"Você já vai começar a tomar hoje?"`, `"Sim, hoje mesmo"`
- `"Selecione pelo menos um dia da semana!"`
- `"Remédio cadastrado com sucesso!"`

### Reminder Form Screen (`reminder_form_screen.dart`)
- `"O título é obrigatório"`, `"Título do Lembrete"`
- `"Vez única"`, `"Semanal"`

---

## 4. Proposed Translations in JSON Format
The following JSON sections contain all the missing translations categorized by function. These blocks should be appended inside the `"web"` object of the respective language files (`pt.json`, `en.json`, and `es.json`):

### Portuguese (`pt.json` additions under `"web"`)
```json
{
  "nav_qr_scan_soon": "Leitura de QR Code via câmera disponível em breve! 📸",
  "dash_disconnect": "Desconectar",
  "dash_sync": "Sincronizar",
  "dash_history_logs": "Histórico & Logs",
  "dash_connected_status": "MediCaixa conectada",
  "dash_offline_status": "Modo Offline",
  "dash_missed_singular": "perdido",
  "dash_missed_plural": "perdidos",
  "dash_register_btn": "REGISTRAR",
  "meds_search_placeholder": "Pesquisar medicamentos...",
  "meds_no_results": "Nenhum medicamento correspondente.",
  "meds_none_registered": "Nenhum medicamento cadastrado.",
  "meds_clear_selection": "Limpar Seleção",
  "meds_cannot_delete_title": "Não é possível excluir",
  "meds_cannot_delete_body": "Não é possível excluir medicamentos em uso por alarmes:\n\n%s\n\nExclua os alarmes primeiro.",
  "meds_delete_confirm_title": "Confirmar Exclusão",
  "meds_deleted_success": "Medicamentos excluídos com sucesso!",
  "meds_name_required": "O nome é obrigatório",
  "meds_form_type_label": "Forma de Apresentação (Tipo)",
  "meds_form_color_label": "Identificação Visual (Cor)",
  "meds_save_changes_btn": "SALVAR ALTERAÇÕES",
  "meds_register_btn": "CADASTRAR",
  "med_type_syrup": "Xarope",
  "med_type_inhaler": "Inalador",
  "med_type_ointment": "Pomada",
  "med_type_other": "Outro",
  "reports_appbar_title": "Relatórios de Adesão",
  "reports_adherence_7d": "Adesão Geral (7 dias)",
  "reports_daily_7d": "Adesão Diária (7 dias)",
  "reports_streak_30d": "Sequência (30 dias)",
  "reports_period_7d": "Distribuição por Período (7 dias)",
  "reports_meds_7d": "Desempenho por Medicamento (7 dias)",
  "reports_calendar_30d": "Calendário de Adesão (30 dias)",
  "reports_no_data_med": "Nenhum dado por medicamento.",
  "reports_heatmap_future": "Futuro",
  "reports_heatmap_alarms_plural": "alarmes",
  "reports_heatmap_alarms_singular": "alarme",
  "day_initial_sunday": "D",
  "day_initial_monday": "S",
  "day_initial_tuesday": "T",
  "day_initial_wednesday": "Q",
  "day_initial_thursday": "Q",
  "day_initial_friday": "S",
  "day_initial_saturday": "S",
  "settings_local_header": "Ajustes Locais",
  "settings_sleep_schedule": "Cronograma de Sono",
  "settings_sleep_label": "Dormir",
  "settings_wake_label": "Acordar",
  "settings_meals_header": "Horários das Refeições",
  "settings_breakfast": "Café da Manhã",
  "settings_lunch": "Almoço",
  "settings_dinner": "Jantar",
  "settings_meals_desc": "Balizam os atalhos \"Antes do café\", \"Depois do almoço\", etc. no alarme.",
  "settings_device_header": "Ajustes da Caixinha",
  "settings_conn_local_network": "Conectado via rede local",
  "settings_conn_standalone": "Modo Standalone (Desconectado)",
  "settings_conn_details": "Endereço IP: %s\nFirmware: %s",
  "settings_conn_standalone_desc": "O app está salvando tudo localmente no SQLite.",
  "settings_change_pair_btn": "Alterar Caixinha / Parear",
  "settings_connect_box_btn": "Conectar com MediCaixa",
  "settings_box_locked_title": "Configurações da Caixinha Bloqueadas",
  "settings_box_locked_desc": "Para alterar as configurações físicas da caixinha (como volume, Wi-Fi e sincronização), você precisa se conectar à sua MediCaixa.",
  "settings_connect_now_btn": "Conectar Agora",
  "settings_box_wifi_title": "Rede Wi-Fi da Caixinha",
  "settings_box_wifi_desc": "Gerencie as conexões de rede do dispositivo",
  "settings_sound_display_header": "Sons e Tela",
  "settings_clock_sync_success": "Relógio sincronizado com o celular!",
  "settings_wifi_save_success": "Rede Wi-Fi salva com sucesso!",
  "settings_wifi_remove_success": "Rede removida com sucesso!",
  "settings_developer_header": "Opções de Desenvolvedor",
  "settings_offline_tests": "Testes Offline (Fixture)",
  "settings_fixture_loaded_toast": "Backup de teste carregado com 25 alarmes, 6 lembretes e medicamentos! 🎉",
  "active_alarm_header": "HORA DO MEDICAMENTO",
  "active_alarm_mark_taken": "MARCAR COMO TOMADO",
  "active_alarm_snooze_10m": "ADIAR 10 MIN",
  "active_alarm_skip": "PULAR DOSE",
  "active_alarm_apply_at": "Aplicar em: %s",
  "snooze_taken_btn": "Tomei",
  "snooze_skip_btn": "Pular",
  "snooze_qty_to_take": "Dose a tomar: ",
  "snooze_dynamic_dose_desc": "Medicamento com Dose Dinâmica (Glicose / Insulina)",
  "snooze_snooze_for": "Adiar por:",
  "snooze_minutes_label": "minutos",
  "snooze_delete_alarm_title": "Excluir Alarme",
  "snooze_delete_alarm_confirm": "Tem certeza que deseja excluir \"%s\"?",
  "snooze_cancel_action": "Cancelar",
  "snooze_delete_action": "Excluir",
  "pair_search_devices": "Buscar Dispositivos",
  "pair_searching": "Buscando MediCaixa na rede...",
  "pair_none_found": "Nenhuma MediCaixa encontrada",
  "pair_help_network": "Certifique-se de que a MediCaixa está ligada e na mesma rede Wi-Fi.",
  "pair_first_time_help": "Como conectar a primeira vez?",
  "pair_connect_by_ip": "Conectar pelo IP",
  "pair_enter_ip_desc": "Insira o IP exibido na tela da MediCaixa:",
  "pair_ip_placeholder": "Digite o IP da caixinha (Ex: 192.168.1.100)",
  "pair_connect_ip_btn": "Conectar via IP",
  "pair_insert_ip_manual": "OU INSERIR IP MANUAL",
  "pair_standalone_title": "Usar sem caixinha (Modo Offline)",
  "pair_standalone_desc": "O aplicativo funcionará com banco de dados local.",
  "pair_connecting_status": "Conectando...",
  "pair_connected_success": "Conectado!",
  "pair_connect_error": "Erro ao conectar",
  "wizard_medication_question": "Qual medicamento deseja agendar?",
  "wizard_medication_new": "+ Novo Medicamento",
  "wizard_mode_question": "Qual o horário e dias da semana?",
  "wizard_mode_routine": "Tomar na rotina diária",
  "wizard_mode_scheduled": "Tem dia e hora certos para tomar",
  "wizard_mode_prn": "Só de vez em quando (Sob demanda)",
  "wizard_prn_interval_question": "Tem que esperar quantas horas antes de repetir a dose?",
  "wizard_prn_max_question": "Qual o máximo de vezes que pode tomar no mesmo dia?",
  "wizard_qty_question": "Qual a quantidade que você toma por vez?",
  "wizard_qty_fixed": "Quantidade Fixa",
  "wizard_qty_fixed_desc": "Sempre a mesma quantidade",
  "wizard_qty_dynamic": "Dose dinâmica",
  "wizard_qty_dynamic_desc": "Se estiver",
  "wizard_qty_dynamic_device": "Qual aparelho de teste você vai usar?",
  "wizard_qty_taper": "Desmame progressivo",
  "wizard_qty_taper_desc": "Doses que diminuem com o tempo",
  "wizard_days_question": "Selecione os dias da semana:",
  "wizard_days_daily": "Todos os dias",
  "wizard_days_daily_desc": "Sem faltar nenhum dia",
  "wizard_days_custom": "Personalizado",
  "wizard_days_custom_desc": "Escolher os dias",
  "wizard_days_monthly": "Mensal (Dia fixo)",
  "wizard_days_monthly_desc": "Sempre no mesmo dia do mês",
  "wizard_days_cycle": "Uso com Pausa (Ciclo)",
  "wizard_days_cycle_desc": "Tomo por X dias e folgo Y dias",
  "wizard_time_question": "Que horas vai ser o seu PRIMEIRO remédio de hoje?",
  "wizard_duration_question": "Por quantos dias o médico mandou tomar?",
  "wizard_duration_continuous": "Uso contínuo (Para sempre)",
  "wizard_duration_temporary": "Tratamento com prazo definido",
  "wizard_duration_temporary_desc": "O médico passou por alguns dias (Ex: Antibiótico)",
  "wizard_summary_title": "RESUMO DO REMÉDIO",
  "wizard_summary_start_today": "Você já vai começar a tomar hoje?",
  "wizard_summary_yes_today": "Sim, hoje mesmo",
  "wizard_error_select_day": "Selecione pelo menos um dia da semana!",
  "wizard_success_toast": "Remédio cadastrado com sucesso!",
  "reminder_title_required": "O título é obrigatório",
  "reminder_form_title": "Título do Lembrete",
  "reminder_freq_once": "Vez única",
  "reminder_freq_weekly": "Semanal",
  "status_taken_late": "Tomado fora hora",
  "status_taken_prn": "Tomado PRN",
  "status_snoozed": "Adiado",
  "status_skipped": "Pulado"
}
```

### English (`en.json` additions under `"web"`)
```json
{
  "nav_qr_scan_soon": "QR Code reading via camera available soon! 📸",
  "dash_disconnect": "Disconnect",
  "dash_sync": "Sync",
  "dash_history_logs": "History & Logs",
  "dash_connected_status": "MediCaixa connected",
  "dash_offline_status": "Offline Mode",
  "dash_missed_singular": "missed",
  "dash_missed_plural": "missed",
  "dash_register_btn": "RECORD",
  "meds_search_placeholder": "Search medications...",
  "meds_no_results": "No matching medications.",
  "meds_none_registered": "No medications registered.",
  "meds_clear_selection": "Clear Selection",
  "meds_cannot_delete_title": "Cannot Delete",
  "meds_cannot_delete_body": "Cannot delete medications in use by alarms:\n\n%s\n\nDelete the alarms first.",
  "meds_delete_confirm_title": "Confirm Deletion",
  "meds_deleted_success": "Medications deleted successfully!",
  "meds_name_required": "Name is required",
  "meds_form_type_label": "Presentation Form (Type)",
  "meds_form_color_label": "Visual Identification (Color)",
  "meds_save_changes_btn": "SAVE CHANGES",
  "meds_register_btn": "REGISTER",
  "med_type_syrup": "Syrup",
  "med_type_inhaler": "Inhaler",
  "med_type_ointment": "Ointment",
  "med_type_other": "Other",
  "reports_appbar_title": "Adherence Reports",
  "reports_adherence_7d": "Overall Adherence (7 days)",
  "reports_daily_7d": "Daily Adherence (7 days)",
  "reports_streak_30d": "Streak (30 days)",
  "reports_period_7d": "Period Distribution (7 days)",
  "reports_meds_7d": "Performance by Medication (7 days)",
  "reports_calendar_30d": "Adherence Calendar (30 days)",
  "reports_no_data_med": "No data per medication.",
  "reports_heatmap_future": "Future",
  "reports_heatmap_alarms_plural": "alarms",
  "reports_heatmap_alarms_singular": "alarm",
  "day_initial_sunday": "S",
  "day_initial_monday": "M",
  "day_initial_tuesday": "T",
  "day_initial_wednesday": "W",
  "day_initial_thursday": "T",
  "day_initial_friday": "F",
  "day_initial_saturday": "S",
  "settings_local_header": "Local Settings",
  "settings_sleep_schedule": "Sleep Schedule",
  "settings_sleep_label": "Sleep",
  "settings_wake_label": "Wake",
  "settings_meals_header": "Meal Times",
  "settings_breakfast": "Breakfast",
  "settings_lunch": "Lunch",
  "settings_dinner": "Dinner",
  "settings_meals_desc": "Sets the shortcuts \"Before breakfast\", \"After lunch\", etc. in the alarm.",
  "settings_device_header": "Box Settings",
  "settings_conn_local_network": "Connected via local network",
  "settings_conn_standalone": "Standalone Mode (Disconnected)",
  "settings_conn_details": "IP Address: %s\nFirmware: %s",
  "settings_conn_standalone_desc": "The app is saving everything locally in SQLite.",
  "settings_change_pair_btn": "Change Box / Pair",
  "settings_connect_box_btn": "Connect with MediCaixa",
  "settings_box_locked_title": "Box Settings Locked",
  "settings_box_locked_desc": "To change physical box settings (like volume, Wi-Fi, and sync), you need to connect to your MediCaixa.",
  "settings_connect_now_btn": "Connect Now",
  "settings_box_wifi_title": "Box Wi-Fi Network",
  "settings_box_wifi_desc": "Manage network connections of the device",
  "settings_sound_display_header": "Sound & Screen",
  "settings_clock_sync_success": "Clock synchronized with phone!",
  "settings_wifi_save_success": "Wi-Fi network saved successfully!",
  "settings_wifi_remove_success": "Network removed successfully!",
  "settings_developer_header": "Developer Options",
  "settings_offline_tests": "Offline Tests (Fixture)",
  "settings_fixture_loaded_toast": "Test backup loaded with 25 alarms, 6 reminders, and medications! 🎉",
  "active_alarm_header": "MEDICATION TIME",
  "active_alarm_mark_taken": "MARK AS TAKEN",
  "active_alarm_snooze_10m": "SNOOZE 10 MIN",
  "active_alarm_skip": "SKIP DOSE",
  "active_alarm_apply_at": "Apply at: %s",
  "snooze_taken_btn": "Took it",
  "snooze_skip_btn": "Skip",
  "snooze_qty_to_take": "Dose to take: ",
  "snooze_dynamic_dose_desc": "Medication with Dynamic Dose (Glucose / Insulin)",
  "snooze_snooze_for": "Snooze for:",
  "snooze_minutes_label": "minutes",
  "snooze_delete_alarm_title": "Delete Alarm",
  "snooze_delete_alarm_confirm": "Are you sure you want to delete \"%s\"?",
  "snooze_cancel_action": "Cancel",
  "snooze_delete_action": "Delete",
  "pair_search_devices": "Search Devices",
  "pair_searching": "Searching for MediCaixa on network...",
  "pair_none_found": "No MediCaixa found",
  "pair_help_network": "Make sure MediCaixa is turned on and on the same Wi-Fi network.",
  "pair_first_time_help": "How to connect for the first time?",
  "pair_connect_by_ip": "Connect by IP",
  "pair_enter_ip_desc": "Enter the IP displayed on the MediCaixa screen:",
  "pair_ip_placeholder": "Type the box IP (E.g.: 192.168.1.100)",
  "pair_connect_ip_btn": "Connect via IP",
  "pair_insert_ip_manual": "OR ENTER IP MANUALLY",
  "pair_standalone_title": "Use without box (Offline Mode)",
  "pair_standalone_desc": "The application will work with a local database.",
  "pair_connecting_status": "Connecting...",
  "pair_connected_success": "Connected!",
  "pair_connect_error": "Error connecting",
  "wizard_medication_question": "Which medication do you want to schedule?",
  "wizard_medication_new": "+ New Medication",
  "wizard_mode_question": "What is the time and days of the week?",
  "wizard_mode_routine": "Take in the daily routine",
  "wizard_mode_scheduled": "Has a set day and time to take",
  "wizard_mode_prn": "Only once in a while (As needed)",
  "wizard_prn_interval_question": "How many hours do you have to wait before repeating the dose?",
  "wizard_prn_max_question": "What is the maximum number of times you can take it in the same day?",
  "wizard_qty_question": "How much do you take at a time?",
  "wizard_qty_fixed": "Fixed Quantity",
  "wizard_qty_fixed_desc": "Always the same quantity",
  "wizard_qty_dynamic": "Dynamic dose",
  "wizard_qty_dynamic_desc": "If it is",
  "wizard_qty_dynamic_device": "Which test device will you use?",
  "wizard_qty_taper": "Progressive tapering",
  "wizard_qty_taper_desc": "Doses that decrease over time",
  "wizard_days_question": "Select the days of the week:",
  "wizard_days_daily": "Every day",
  "wizard_days_daily_desc": "Without missing any day",
  "wizard_days_custom": "Custom",
  "wizard_days_custom_desc": "Choose the days",
  "wizard_days_monthly": "Monthly (Fixed date)",
  "wizard_days_monthly_desc": "Always on the same day of the month",
  "wizard_days_cycle": "Use with Pause (Cycle)",
  "wizard_days_cycle_desc": "Take for X days and rest Y days",
  "wizard_time_question": "What time will your FIRST medication be today?",
  "wizard_duration_question": "For how many days did the doctor tell you to take it?",
  "wizard_duration_continuous": "Continuous use (Forever)",
  "wizard_duration_temporary": "Treatment with defined period",
  "wizard_duration_temporary_desc": "The doctor prescribed for a few days (E.g.: Antibiotic)",
  "wizard_summary_title": "MEDICATION SUMMARY",
  "wizard_summary_start_today": "Are you going to start taking it today?",
  "wizard_summary_yes_today": "Yes, today",
  "wizard_error_select_day": "Select at least one day of the week!",
  "wizard_success_toast": "Medication registered successfully!",
  "reminder_title_required": "Title is required",
  "reminder_form_title": "Reminder Title",
  "reminder_freq_once": "Once",
  "reminder_freq_weekly": "Weekly",
  "status_taken_late": "Taken late",
  "status_taken_prn": "Taken PRN",
  "status_snoozed": "Snoozed",
  "status_skipped": "Skipped"
}
```

### Spanish (`es.json` additions under `"web"`)
```json
{
  "nav_qr_scan_soon": "¡Lectura de código QR mediante cámara disponible pronto! 📸",
  "dash_disconnect": "Desconectar",
  "dash_sync": "Sincronizar",
  "dash_history_logs": "Historial y Registros",
  "dash_connected_status": "MediCaixa conectada",
  "dash_offline_status": "Modo sin conexión",
  "dash_missed_singular": "perdido",
  "dash_missed_plural": "perdidos",
  "dash_register_btn": "REGISTRAR",
  "meds_search_placeholder": "Buscar medicamentos...",
  "meds_no_results": "Ningún medicamento coincidente.",
  "meds_none_registered": "Ningún medicamento registrado.",
  "meds_clear_selection": "Limpar selección",
  "meds_cannot_delete_title": "No se puede eliminar",
  "meds_cannot_delete_body": "No se puede eliminar medicamentos en uso por alarmas:\n\n%s\n\nElimine las alarmas primero.",
  "meds_delete_confirm_title": "Confirmar eliminación",
  "meds_deleted_success": "¡Medicamentos eliminados con éxito!",
  "meds_name_required": "El nombre es obligatorio",
  "meds_form_type_label": "Forma de presentación (Tipo)",
  "meds_form_color_label": "Identificación visual (Color)",
  "meds_save_changes_btn": "GUARDAR CAMBIOS",
  "meds_register_btn": "REGISTRAR",
  "med_type_syrup": "Jarabe",
  "med_type_inhaler": "Inhalador",
  "med_type_ointment": "Pomada",
  "med_type_other": "Otro",
  "reports_appbar_title": "Informes de adherencia",
  "reports_adherence_7d": "Adherencia general (7 días)",
  "reports_daily_7d": "Adherencia diaria (7 días)",
  "reports_streak_30d": "Racha (30 días)",
  "reports_period_7d": "Distribución por período (7 días)",
  "reports_meds_7d": "Desempeño por medicamento (7 días)",
  "reports_calendar_30d": "Calendario de adherencia (30 días)",
  "reports_no_data_med": "Sin datos por medicamento.",
  "reports_heatmap_future": "Futuro",
  "reports_heatmap_alarms_plural": "alarmas",
  "reports_heatmap_alarms_singular": "alarma",
  "day_initial_sunday": "D",
  "day_initial_monday": "L",
  "day_initial_tuesday": "M",
  "day_initial_wednesday": "M",
  "day_initial_thursday": "J",
  "day_initial_friday": "V",
  "day_initial_saturday": "S",
  "settings_local_header": "Ajustes locales",
  "settings_sleep_schedule": "Cronograma de sueño",
  "settings_sleep_label": "Dormir",
  "settings_wake_label": "Despertar",
  "settings_meals_header": "Horarios de comidas",
  "settings_breakfast": "Desayuno",
  "settings_lunch": "Almuerzo",
  "settings_dinner": "Cena",
  "settings_meals_desc": "Define los atajos \"Antes del desayuno\", \"Después del almuerzo\", etc. en la alarma.",
  "settings_device_header": "Ajustes de la caja",
  "settings_conn_local_network": "Conectado por red local",
  "settings_conn_standalone": "Modo independiente (Desconectado)",
  "settings_conn_details": "Dirección IP: %s\nFirmware: %s",
  "settings_conn_standalone_desc": "La aplicación está guardando todo localmente en SQLite.",
  "settings_change_pair_btn": "Cambiar caja / Vincular",
  "settings_connect_box_btn": "Conectar con MediCaixa",
  "settings_box_locked_title": "Ajustes de la caja bloqueados",
  "settings_box_locked_desc": "Para cambiar los ajustes físicos de la caja (como volumen, Wi-Fi y sinc), debe conectarse a su MediCaixa.",
  "settings_connect_now_btn": "Conectar ahora",
  "settings_box_wifi_title": "Red Wi-Fi de la caja",
  "settings_box_wifi_desc": "Gestione las conexiones de red del dispositivo",
  "settings_sound_display_header": "Sonidos y pantalla",
  "settings_clock_sync_success": "¡Reloj sincronizado con el móvil!",
  "settings_wifi_save_success": "¡Red Wi-Fi guardada con éxito!",
  "settings_wifi_remove_success": "¡Red eliminada con éxito!",
  "settings_developer_header": "Opciones de desarrollador",
  "settings_offline_tests": "Pruebas sin conexión (Fixture)",
  "settings_fixture_loaded_toast": "¡Respaldo de prueba cargado con 25 alarmas, 6 recordatorios y medicamentos! 🎉",
  "active_alarm_header": "HORA DEL MEDICAMENTO",
  "active_alarm_mark_taken": "MARCAR COMO TOMADO",
  "active_alarm_snooze_10m": "POSPONER 10 MIN",
  "active_alarm_skip": "OMITIR DOSIS",
  "active_alarm_apply_at": "Aplicar en: %s",
  "snooze_taken_btn": "Lo tomé",
  "snooze_skip_btn": "Omitir",
  "snooze_qty_to_take": "Dosis a tomar: ",
  "snooze_dynamic_dose_desc": "Medicamento con dosis dinámica (Glucemia / Insulina)",
  "snooze_snooze_for": "Posponer por:",
  "snooze_minutes_label": "minutos",
  "snooze_delete_alarm_title": "Eliminar alarma",
  "snooze_delete_alarm_confirm": "¿Está seguro de que desea eliminar \"%s\"?",
  "snooze_cancel_action": "Cancelar",
  "snooze_delete_action": "Eliminar",
  "pair_search_devices": "Buscar dispositivos",
  "pair_searching": "Buscando MediCaixa en la red...",
  "pair_none_found": "Ninguna MediCaixa encontrada",
  "pair_help_network": "Asegúrese de que MediCaixa está encendida y en la misma red Wi-Fi.",
  "pair_first_time_help": "¿Cómo conectar la primera vez?",
  "pair_connect_by_ip": "Conectar por IP",
  "pair_enter_ip_desc": "Ingrese la IP que se muestra en la pantalla de MediCaixa:",
  "pair_ip_placeholder": "Escriba la IP de la caja (Ej: 192.168.1.100)",
  "pair_connect_ip_btn": "Conectar por IP",
  "pair_insert_ip_manual": "O INGRESE LA IP MANUALMENTE",
  "pair_standalone_title": "Usar sin caja (Modo sin conexión)",
  "pair_standalone_desc": "La aplicación funcionará con una base de datos local.",
  "pair_connecting_status": "Conectando...",
  "pair_connected_success": "¡Conectado!",
  "pair_connect_error": "Error al conectar",
  "wizard_medication_question": "¿Qué medicamento desea programar?",
  "wizard_medication_new": "+ Nuevo Medicamento",
  "wizard_mode_question": "¿Cuál es el horario y días de la semana?",
  "wizard_mode_routine": "Tomar en la rutina diaria",
  "wizard_mode_scheduled": "Tiene día y hora específicos para tomar",
  "wizard_mode_prn": "Solo de vez en cuando (A demanda)",
  "wizard_prn_interval_question": "¿Cuántas horas debe esperar antes de repetir la dosis?",
  "wizard_prn_max_question": "¿Cuál es el máximo de veces que puede tomar en el mismo día?",
  "wizard_qty_question": "¿Qué cantidad toma por vez?",
  "wizard_qty_fixed": "Cantidad fija",
  "wizard_qty_fixed_desc": "Siempre la misma cantidad",
  "wizard_qty_dynamic": "Dosis dinámica",
  "wizard_qty_dynamic_desc": "Si está",
  "wizard_qty_dynamic_device": "¿Qué dispositivo de prueba usará?",
  "wizard_qty_taper": "Destete progresivo",
  "wizard_qty_taper_desc": "Dosis que disminuyen con el tiempo",
  "wizard_days_question": "Seleccione los días de la semana:",
  "wizard_days_daily": "Todos los días",
  "wizard_days_daily_desc": "Sin faltar ningún día",
  "wizard_days_custom": "Personalizado",
  "wizard_days_custom_desc": "Elegir los días",
  "wizard_days_monthly": "Mensal (Día fijo)",
  "wizard_days_monthly_desc": "Siempre el mismo día del mes",
  "wizard_days_cycle": "Uso con pausa (Ciclo)",
  "wizard_days_cycle_desc": "Tomo por X días y descanso Y días",
  "wizard_time_question": "¿A qué hora será su PRIMERA medicina hoy?",
  "wizard_duration_question": "¿Por cuántos días le recetó el médico tomarlo?",
  "wizard_duration_continuous": "Uso continuo (Para siempre)",
  "wizard_duration_temporary": "Tratamiento con plazo definido",
  "wizard_duration_temporary_desc": "El médico lo recetó por unos días (Ej: Antibiótico)",
  "wizard_summary_title": "RESUMEN DE MEDICACIÓN",
  "wizard_summary_start_today": "¿Va a empezar a tomarlo hoy?",
  "wizard_summary_yes_today": "Sí, hoy mismo",
  "wizard_error_select_day": "¡Seleccione al menos un día de la semana!",
  "wizard_success_toast": "¡Medicamento registrado con éxito!",
  "reminder_title_required": "El nombre es obligatorio",
  "reminder_form_title": "Título del recordatorio",
  "reminder_freq_once": "Una vez",
  "reminder_freq_weekly": "Semanal",
  "status_taken_late": "Tomado fuera de hora",
  "status_taken_prn": "Tomado PRN",
  "status_snoozed": "Pospuesto",
  "status_skipped": "Omitido"
}
```
