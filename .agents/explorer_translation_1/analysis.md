# Relatório de Auditoria de Tradução — MediCaixa App

Este relatório identifica todas as strings em português codificadas diretamente (hardcoded) nos arquivos fonte do aplicativo MediCaixa, abrangendo as áreas solicitadas (AppShell, Dashboard, Medications, Reports, Settings, além dos modais SnoozeModal, ReminderActionModal, e Diálogos de Exclusão/Reset).

Para cada string encontrada, apresentamos o caminho do arquivo, o número da linha, o conteúdo original e a recomendação de substituição por meio da função global de tradução `t('key')` ou `t('key', [args])`.

---

## 1. AppShell (`lib/core/presentation/app_shell.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 57 | `'Leitura de QR Code via câmera disponível em breve! 📸'` | `t('qr_camera_soon')` | Novo: `"qr_camera_soon": "Leitura de QR Code via câmera disponível em breve! 📸"` |
| 86 | `'Início'` | `t('nav_home')` | Já existe no JSON |
| 91 | `'Remédios'` | `t('nav_meds')` | Já existe no JSON |
| 96 | `'Relatórios'` | `t('nav_stats')` | Já existe no JSON |
| 101 | `'Ajustes'` | `t('nav_settings')` | Já existe no JSON |
| 152 | `'Início'` | `t('nav_home')` | Já existe no JSON |
| 157 | `'Remédios'` | `t('nav_meds')` | Já existe no JSON |
| 162 | `'Relatórios'` | `t('nav_stats')` | Já existe no JSON |
| 167 | `'Ajustes'` | `t('nav_settings')` | Já existe no JSON |

---

## 2. Dashboard Feature

### 2.1 Dashboard Screen (`lib/features/dashboard/presentation/dashboard_screen.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 64 | `'Paciente'` | `t('default_patient_name')` | Novo fallback: `"default_patient_name": "Paciente"` |
| 70-75 | `'Bom dia'`, `'Boa tarde'`, `'Boa noite'` | `t('greeting_morning')`, `t('greeting_afternoon')`, `t('greeting_evening')` | Já existem no JSON |
| 150 | `'$greeting, $patientName!'` | `t('greeting_format', [greeting, patientName])` ou `${t(greetingKey)}, $patientName!` | Substituir usando a lógica de chaves dinâmicas baseadas na hora. |
| 175 | `'Desconectar'` | `t('tooltip_disconnect')` | Novo: `"tooltip_disconnect": "Desconectar"` |
| 190 | `'Sincronizar'` | `t('tooltip_sync')` | Novo: `"tooltip_sync": "Sincronizar"` |
| 199 | `'Histórico & Logs'` | `t('tooltip_history_logs')` | Novo: `"tooltip_history_logs": "Histórico & Logs"` |
| 245 | `'MediCaixa conectada'` | `t('status_connected')` | Novo: `"status_connected": "MediCaixa conectada"` |
| 246 | `'Modo Offline'` | `t('status_offline')` | Novo: `"status_offline": "Modo Offline"` |
| 333 | `'Novo Alarme'` | `t('tooltip_new_alarm')` | Novo: `"tooltip_new_alarm": "Novo Alarme"` |
| 363 | `'Sob Demanda (PRN)'` | `t('alarm_freq_prn')` | Já existe no JSON |
| 373 | `'Manhã'` | `t('section_morning')` | Já existe no JSON |
| 383 | `'Tarde'` | `t('section_afternoon')` | Já existe no JSON |
| 393 | `'Noite'` | `t('section_night')` | Já existe no JSON |
| 536 | `'$label ($totalCount)'` | `${t(labelKey)} ($totalCount)` | Onde `labelKey` é obtido dinamicamente. |
| 546 | `'• $missedCount perdido${missedCount > 1 ? 's' : ''}'` | `missedCount == 1 ? t('missed_count_singular', [missedCount]) : t('missed_count_plural', [missedCount])` | Novo: `"missed_count_singular": "• %d perdido"`, `"missed_count_plural": "• %d perdidos"` |
| 583 | `'Nenhum alarme neste período'` | `t('no_alarms_period')` | Já existe no JSON |
| 668 | `'Lembretes'` | `t('section_reminders')` | Já existe no JSON |
| 717 | `'Uso Sob Demanda'` | `t('dialog_prn_title')` | Novo: `"dialog_prn_title": "Uso Sob Demanda"` |
| 718 | `'Deseja registrar o uso deste medicamento agora?'` | `t('prn_confirm_take')` | Já existe no JSON |
| 722 | `'CANCELAR'` | `t('cancel_btn').toUpperCase()` | Já existe no JSON |
| 726 | `'REGISTRAR'` | `t('btn_register')` | Novo: `"btn_register": "REGISTRAR"` |
| 738 | `'Medicamento registrado com sucesso!'` | `t('prn_taken_toast')` | Novo: `"prn_taken_toast": "Medicamento registrado com sucesso!"` |
| 807-810 | Nomes dos dias da semana e meses em `_formatPortugueseDate` | Utilizar `intl` com local dinâmico | Ex: `DateFormat.EEEE(locale)` ou `t('day_...')` |
| 817 | Iniciais dos dias `['D', 'S', 'T', 'Q', 'Q', 'S', 'S']` | Utilizar `intl` com local dinâmico | Ex: `DateFormat.E(locale)` ou chaves de tradução. |

### 2.2 Alarm Card Widget (`lib/features/dashboard/presentation/widgets/alarm_card_widget.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 49 | `'Excluído'` | `t('badge_deleted')` | Novo: `"badge_deleted": "Excluído"` |
| 54 | `'Suspenso'` | `t('badge_paused_indefinite')` | Já existe no JSON |
| 57 | `'Suspenso até ${...}'` | `t('badge_paused_until', [formattedDate])` | Já existe no JSON (aceita argumento) |
| 62 | `'Inativo'` | `t('badge_inactive')` | Já existe no JSON |
| 66 | `'Tomado'` | `t('badge_taken')` | Já existe no JSON |
| 70 | `'Perdido'` | `t('badge_missed')` | Já existe no JSON |
| 74 | `'Adiado'` | `t('badge_snoozed')` | Já existe no JSON |
| 86 | `'Sob Demanda'` | `t('alarm_freq_prn_short')` | Novo: `"alarm_freq_prn_short": "Sob Demanda"` |
| 92 | `'$origTime (+${alarm.snoozeMin}min)'` | `t('snoozed_time_info', [origTime, alarm.snoozeMin])` | Novo: `"snoozed_time_info": "%s (+%dmin)"` |
| 281 | `' · Dose ${alarm.doseNum}$doseTotalStr'` | `t('dose_info_fmt', [alarm.doseNum, doseTotalStr])` | Novo: `"dose_info_fmt": " · Dose %s%s"` |
| 289 | `' · Pausa'` | `t('cycle_paused')` | Novo: `"cycle_paused": " · Pausa"` |
| 290 | `' · Dia ${...}/${...}'` | `t('cycle_day_fmt', [current, total])` | Novo: `"cycle_day_fmt": " · Dia %d/%d"` |
| 305 | `' · Etapa ${...}/${...}'` | `t('taper_stage_fmt', [current, total])` | Novo: `"taper_stage_fmt": " · Etapa %d/%d"` |
| 322 | `' · ${alarm.intervalHours}h em ${alarm.intervalHours}h'` | `t('interval_hours_fmt', [hours])` | Novo: `"interval_hours_fmt": " · A cada %dh"` |
| 333 | `' · 📍 Próximo local: $nextSite'` | `t('next_site_rotation', [nextSite])` | Novo: `"next_site_rotation": " · 📍 Próximo local: %s"` |
| 367 | `'comp.'` | `t('med_type_tablet_short')` | Novo: `"med_type_tablet_short": "comp."` |
| 369 | `'cáps.'` | `t('med_type_capsule_short')` | Novo: `"med_type_capsule_short": "cáps."` |
| 371 | `'gotas'` | `t('med_type_drops_short')` | Novo: `"med_type_drops_short": "gotas"` |
| 374 | `'dose'` | `t('med_type_dose_short')` | Novo: `"med_type_dose_short": "dose"` |
| 376 | `'adesivo'` | `t('med_type_patch_short')` | Novo: `"med_type_patch_short": "adesivo"` |
| 378 | `'injeção'` | `t('med_type_injection_short')` | Novo: `"med_type_injection_short": "injeção"` |
| 380 | `'inalação'` | `t('med_type_inhalation_short')` | Novo: `"med_type_inhalation_short": "inalação"` |
| 382 | `'supos.'` | `t('med_type_suppos_short')` | Novo: `"med_type_suppos_short": "supos."` |
| 390 | `'${alarm.durationDays} dias'` | `t('duration_days_fmt', [alarm.durationDays])` | Novo: `"duration_days_fmt": "%d dias"` |
| 393 | `'Diário'` | `t('freq_daily_label')` | Novo: `"freq_daily_label": "Diário"` |
| 400 | `'Seg-Sex'` | `t('freq_weekdays_short')` | Novo: `"freq_weekdays_short": "Seg-Sex"` |
| 402 | Iniciais de dias `['D', 'S', 'T', 'Q', 'Q', 'S', 'S']` | Utilizar `intl` dinâmico ou tradução | Idem à seção anterior. |
| 434 | `'⚡ Em jejum'` | `t('spec_empty_stomach_short')` | Já existe no JSON |
| 436 | `'🍽️ Com comida'` | `t('spec_with_food_short')` | Já existe no JSON |
| 438 | `'👅 Sublingual'` | `t('spec_sublingual_short')` | Novo: `"spec_sublingual_short": "👅 Sublingual"` |
| 440 | `'🌙 Antes de dormir'` | `t('spec_before_sleep_short')` | Novo: `"spec_before_sleep_short": "🌙 Antes de dormir"` |
| 442 | `'🍴 Após refeição'` | `t('spec_after_meal_short')` | Novo: `"spec_after_meal_short": "🍴 Após refeição"` |
| 444 | `'💧 Com água'` | `t('spec_with_water_short')` | Novo: `"spec_with_water_short": "💧 Com água"` |
| 475 | `'Tomar Agora'` | `t('prn_take_now')` | Já existe no JSON |
| 477 | `'Limite Diário Atingido ($dosesToday/${...})'` | `t('prn_limit_reached_fmt', [dosesToday, limit])` | Novo: `"prn_limit_reached_fmt": "Limite Diário Atingido (%d/%d)"` |
| 480 | `'Aguarde $waitStr (Intervalo)'` | `t('prn_wait_fmt', [waitStr])` | Novo: `"prn_wait_fmt": "Aguarde %s (Intervalo)"` |

### 2.3 Calendar Strip Widget (`lib/features/dashboard/presentation/widgets/calendar_strip_widget.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 258, 326 | `DateFormat('MMM', 'pt_BR')` | `DateFormat('MMM', AppLocalizations.locale)` | Tornar o Locale do DateFormat reativo/localizado |
| 426 | `DateFormat('E', 'pt_BR')` | `DateFormat('E', AppLocalizations.locale)` | Tornar o Locale do DateFormat reativo/localizado |
| 535 | `'HOJE'` | `t('today_btn').toUpperCase()` | Já existe no JSON |
| 535 | `'VOLTAR PARA HOJE'` | `t('today_btn_return').toUpperCase()` | Já existe no JSON |

### 2.4 Day Summary Widget (`lib/features/dashboard/presentation/widgets/day_summary_widget.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 22 | `'Tomados'` | `t('stats_taken')` | Já existe no JSON |
| 31 | `'Pendentes'` | `t('stats_pending')` | Novo: `"stats_pending": "Pendentes"` |
| 40 | `'Perdidos'` | `t('stats_missed')` | Já existe no JSON |

### 2.5 Health Banner Widget (`lib/features/dashboard/presentation/widgets/health_banner_widget.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 63, 97 | `'Sua saúde em dia'` | `t('health_ok')` | Já existe no JSON |
| 110 | `'Sua saúde está em dia'` | `t('health_ok')` | Reutilizar `health_ok` |
| 119 | `'Sua saúde está em atenção'` | `t('health_warn')` | Já existe no JSON (`"health_warn": "Atenção com seus remédios"`) |
| 128 | `'Sua saúde está em risco'` | `t('health_risk')` | Já existe no JSON (`"health_risk": "Cuidado: adesão baixa"`) |
| 137 | `'Sua saúde está em alto risco'` | `t('health_danger')` | Já existe no JSON (`"health_danger": "Alerta: adesão muito baixa"`) |

### 2.6 Reminder Card Widget (`lib/features/dashboard/presentation/widgets/reminder_card_widget.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 170 | `'Hoje'` | `t('today_btn')` | Já existe no JSON |
| 171 | `'Amanhã'` | `t('proximity_tomorrow')` | Novo: `"proximity_tomorrow": "Amanhã"` |
| 172 | `'Ontem'` | `t('proximity_yesterday')` | Novo: `"proximity_yesterday": "Ontem"` |
| 173 | `'Em $diffDays dias'` | `t('proximity_in_days', [diffDays])` | Novo: `"proximity_in_days": "Em %d dias"` |
| 174 | `'Há ${diffDays.abs()} dias'` | `t('proximity_ago_days', [diffDays.abs()])` | Novo: `"proximity_ago_days": "Há %d dias"` |
| 180 | `'Vez única'` | `t('rem_once_label')` | Novo: `"rem_once_label": "Vez única"` |
| 185 | `'A cada $interval $label'` | `t('rem_every_interval_fmt', [interval, label])` | Novo: `"rem_every_interval_fmt": "A cada %d %s"` |
| 191 | `'Diário'` / `'dias'` | `t('freq_daily')` / `t('days_lowercase')` | Novos: `"freq_daily": "Diário"`, `"days_lowercase": "dias"` |
| 193 | `'Semanal'` / `'semanas'` | `t('freq_weekly')` / `t('weeks_lowercase')` | Novos: `"freq_weekly": "Semanal"`, `"weeks_lowercase": "semanas"` |
| 195 | `'Mensal'` / `'meses'` | `t('freq_monthly')` / `t('months_lowercase')` | Novos: `"freq_monthly": "Mensal"`, `"months_lowercase": "meses"` |
| 197 | `'Anual'` / `'anos'` | `t('freq_yearly')` / `t('years_lowercase')` | Novos: `"freq_yearly": "Anual"`, `"years_lowercase": "anos"` |
| 199 | `'período'` | `t('freq_period_lowercase')` | Novo: `"freq_period_lowercase": "período"` |

---

## 3. Medications Feature

### 3.1 Medications List Screen (`lib/features/medications/presentation/medications_list_screen.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 42 | `'Comprimido'` | `t('med_type_tablet')` | Já existe no JSON |
| 44 | `'Cápsula'` | `t('med_type_capsule')` | Já existe no JSON |
| 46 | `'Gotas'` | `t('med_type_drops')` | Já existe no JSON |
| 48 | `'Xarope'` | `t('med_type_syrup')` | Novo: `"med_type_syrup": "Xarope"` |
| 50 | `'Inalador'` | `t('med_type_inhaler')` | Novo: `"med_type_inhaler": "Inalador"` |
| 52 | `'Injetável'` | `t('med_type_injectable')` | Novo: `"med_type_injectable": "Injetável"` |
| 54 | `'Pomada'` | `t('med_type_ointment')` | Novo: `"med_type_ointment": "Pomada"` |
| 57 | `'Outro'` | `t('med_type_other')` | Novo: `"med_type_other": "Outro"` |
| 102 | `'Não é possível excluir'` | `t('dialog_delete_blocked_title')` | Novo: `"dialog_delete_blocked_title": "Não é possível excluir"` |
| 104-106 | `'Não é possível excluir medicamentos em uso por alarmes...'` | `t('dialog_delete_blocked_desc', [inUseText])` | Novo: `"dialog_delete_blocked_desc": "Não é possível excluir medicamentos em uso por alarmes:\n\n%s\n\nExclua os alarmes primeiro."` |
| 111 | `'OK'` | `t('ok_btn')` | Novo: `"ok_btn": "OK"` |
| 124 | `'Confirmar Exclusão'` | `t('dialog_confirm_delete_title')` | Novo: `"dialog_confirm_delete_title": "Confirmar Exclusão"` |
| 125 | `'Excluir ${_selectedMeds.length} medicamento(s)?...'` | `t('dialog_confirm_delete_meds_desc', [_selectedMeds.length])` | Novo: `"dialog_confirm_delete_meds_desc": "Excluir %d medicamento(s)?\n\nEsta ação não pode ser desfeita."` |
| 129 | `'CANCELAR'` | `t('cancel_btn').toUpperCase()` | Já existe no JSON |
| 133 | `'EXCLUIR'` | `t('btn_delete_caps')` | Novo: `"btn_delete_caps": "EXCLUIR"` |
| 147 | `'Medicamentos excluídos com sucesso!'` | `t('meds_deleted_toast')` | Novo: `"meds_deleted_toast": "Medicamentos excluídos com sucesso!"` |
| 157 | `'Erro ao excluir: $e'` | `t('meds_delete_error', [error])` | Novo: `"meds_delete_error": "Erro ao excluir: %s"` |
| 196 | `'Remédios'` | `t('meds_title')` | Já existe no JSON |
| 205 | `'Gerenciar Medicamentos'` | `t('meds_subtitle')` | Já existe no JSON |
| 225 | `_isSelectionMode ? 'Cancelar' : 'Selecionar'` | `_isSelectionMode ? t('meds_cancel') : t('meds_select')` | Já existem no JSON |
| 241-243 | `'1 medicamento'` / `' medicamentos'` | `allMeds.length == 1 ? t('meds_count_singular') : t('meds_count_plural', [count])` | Já existem no JSON (com argumentos) |
| 255 | `'Pesquisar medicamentos...'` | `t('search_meds_placeholder')` | Novo: `"search_meds_placeholder": "Pesquisar medicamentos..."` |
| 288 | `'Nenhum medicamento correspondente.'` | `t('meds_search_no_results')` | Novo: `"meds_search_no_results": "Nenhum medicamento correspondente."` |
| 289 | `'Nenhum medicamento cadastrado.'` | `t('meds_list_empty')` | Novo: `"meds_list_empty": "Nenhum medicamento cadastrado."` |
| 422 | `'Limpar Seleção'` | `t('btn_clear_selection')` | Novo: `"btn_clear_selection": "Limpar Seleção"` |
| 435 | `'Excluir (${_selectedMeds.length})'` | `t('btn_delete_count_fmt', [_selectedMeds.length])` | Novo: `"btn_delete_count_fmt": "Excluir (%d)"` |

### 3.2 Medication Form Screen (`lib/features/medications/presentation/medication_form_screen.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 70 | `'Medicamento atualizado com sucesso!'` | `t('meds_updated_toast')` | Novo: `"meds_updated_toast": "Medicamento atualizado com sucesso!"` |
| 70 | `'Medicamento cadastrado com sucesso!'` | `t('meds_added_toast')` | Novo: `"meds_added_toast": "Medicamento cadastrado com sucesso!"` |
| 80 | `'Erro ao salvar medicamento: $e'` | `t('meds_save_error', [error])` | Novo: `"meds_save_error": "Erro ao salvar medicamento: %s"` |
| 92 | `'Excluir Medicamento'` | `t('med_delete_btn')` | Já existe no JSON (`"med_delete_btn": "Excluir Medicamento"`) |
| 93 | `'Deseja mesmo excluir este medicamento do cadastro?'` | `t('dialog_delete_med_desc')` | Novo: `"dialog_delete_med_desc": "Deseja mesmo excluir este medicamento do cadastro?"` |
| 97, 259 | `'CANCELAR'`, `'EXCLUIR'` | `t('cancel_btn').toUpperCase()`, `t('btn_delete_caps')` | Reutilizar chaves existentes / sugeridas |
| 115 | `'Medicamento excluído com sucesso!'` | `t('med_deleted_toast')` | Novo: `"med_deleted_toast": "Medicamento excluído com sucesso!"` |
| 125 | `'Erro ao excluir: $e'` | `t('med_delete_error', [error])` | Novo: `"med_delete_error": "Erro ao excluir: %s"` |
| 141 | `isEdit ? 'Editar...': 'Cadastrar...'` | `isEdit ? t('edit_med_title') : t('new_med_title')` | Já existem no JSON |
| 158 | `'Nome do Medicamento'` | `t('med_name_label_clean')` | Novo: `"med_name_label_clean": "Nome do Medicamento"` |
| 159 | `'Ex: Paracetamol, Ibuprofeno'` | `t('med_name_hint')` | Novo: `"med_name_hint": "Ex: Paracetamol, Ibuprofeno"` |
| 170 | `'O nome é obrigatório'` | `t('med_name_required')` | Novo: `"med_name_required": "O nome é obrigatório"` |
| 182 | `'Dosagem padrão (Opcional)'` | `t('med_dosage_label_optional')` | Novo: `"med_dosage_label_optional": "Dosagem padrão (Opcional)"` |
| 183 | `'Ex: 500mg, 1 comprimido'` | `t('med_dosage_placeholder')` | Já existe no JSON (`"med_dosage_placeholder": "Ex: 50mg"`) ou criar similar |
| 202 | `'Forma de Apresentação (Tipo)'` | `t('med_type_card_title')` | Novo: `"med_type_card_title": "Forma de Apresentação (Tipo)"` |
| 238 | `'Identificação Visual (Cor)'` | `t('med_color_label')` | Já existe no JSON (`"med_color_label": "Cor de Identificação"`) |
| 274 | `'SALVAR ALTERAÇÕES'` / `'CADASTRAR'` | `isEdit ? t('btn_save_changes_caps') : t('btn_register_caps')` | Novos: `"btn_save_changes_caps": "SALVAR ALTERAÇÕES"`, `"btn_register_caps": "CADASTRAR"` |

---

## 4. Reports & History Feature

### 4.1 Reports Screen (`lib/features/reports/presentation/reports_screen.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 24 | `'Relatórios de Adesão'` | `t('reports_screen_title')` | Novo: `"reports_screen_title": "Relatórios de Adesão"` |
| 38 | `'Adesão Geral (7 dias)'` | `t('reports_general_adherence_7d')` | Novo: `"reports_general_adherence_7d": "Adesão Geral (7 dias)"` |
| 50 | `'Adesão Diária (7 dias)'` | `t('reports_daily_adherence_7d')` | Novo: `"reports_daily_adherence_7d": "Adesão Diária (7 dias)"` |
| 57 | `'Sequência (30 dias)'` | `t('stats_streak_30d')` | Novo: `"stats_streak_30d": "Sequência (30 dias)"` |
| 68 | `'Distribuição por Período (7 dias)'` | `t('reports_period_distribution_7d')` | Novo: `"reports_period_distribution_7d": "Distribuição por Período (7 dias)"` |
| 84 | `'Todos'` (Value Check) | `stats_filter_all` | Já existe no JSON |
| 86 | `'Desempenho por Medicamento (7 dias)'` | `t('reports_med_performance_7d')` | Novo: `"reports_med_performance_7d": "Desempenho por Medicamento (7 dias)"` |
| 96 | `'Calendário de Adesão (30 dias)'` | `t('reports_adherence_calendar_30d')` | Novo: `"reports_adherence_calendar_30d": "Calendário de Adesão (30 dias)"` |

### 4.2 Medication Filter Bar (`lib/features/reports/presentation/widgets/medication_filter_bar.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 38 | `med` | `med == 'Todos' ? t('stats_filter_all') : med` | Traduzir o filtro global de forma visual |

### 4.3 Donut Chart Widget (`lib/features/reports/presentation/widgets/donut_chart.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 135 | `'Adesão'` | `t('stats_adherence_label')` | Já existe no JSON |
| 152 | `'Tomados'` | `t('stats_taken')` | Já existe no JSON |
| 154 | `'Perdidos'` | `t('stats_missed')` | Já existe no JSON |
| 156 | `'Pulados'` | `t('stats_skipped')` | Já existe no JSON |

### 4.4 Streak Dots Widget (`lib/features/reports/presentation/widgets/streak_dots.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 91, 146 | `'dia'` / `'dias'` | `currentStreak == 1 ? t('streak_day_singular') : t('streak_day_plural')` | Novo: `"streak_day_singular": "dia"`, `"streak_day_plural": "dias"` |
| 100 | `'Sequência Atual'` | `t('stats_streak_current_title')` | Novo: `"stats_streak_current_title": "Sequência Atual"` |
| 114 | `'Histórico (14 dias)'` | `t('stats_streak_history_14d')` | Novo: `"stats_streak_history_14d": "Histórico (14 dias)"` |
| 139 | `'Melhor Sequência:'` | `t('stats_streak_best_title')` | Novo: `"stats_streak_best_title": "Melhor Sequência:"` |

### 4.5 Period Distribution Widget (`lib/features/reports/presentation/widgets/period_distribution.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 91 | `'Manhã'` | `t('stats_period_morning')` | Já existe no JSON |
| 99 | `'Tarde'` | `t('stats_period_afternoon')` | Já existe no JSON |
| 107 | `'Noite'` | `t('stats_period_night')` | Já existe no JSON |

### 4.6 Medication Performance Widget (`lib/features/reports/presentation/widgets/medication_performance.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 20 | `'Nenhum dado por medicamento.'` | `t('stats_med_no_data_short')` | Novo: `"stats_med_no_data_short": "Nenhum dado por medicamento."` |

### 4.7 Monthly Heatmap Widget (`lib/features/reports/presentation/widgets/monthly_heatmap.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 36 | Headers `['D', 'S', 'T', 'Q', 'Q', 'S', 'S']` | Chaves localizadas / `intl` | Tradução ou Array indexado |
| 102 | `'Futuro'` | `t('stats_future_day')` | Novo: `"stats_future_day": "Futuro"` |
| 103 | `'... (alarmes)'` | `t('stats_heatmap_tooltip_fmt', [pct, count])` | Novo: `"stats_heatmap_tooltip_fmt": "%d%% (%d alarmes)"` |
| 178 | `'Sem dados'` | `t('stats_no_data')` | Já existe no JSON |

### 4.8 History Screen (`lib/features/history/presentation/history_screen.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 20 | `'Hoje às $timeStr'` | `t('today_at_time', [timeStr])` | Novo: `"today_at_time": "Hoje às %s"` |
| 22 | `'Ontem às $timeStr'` | `t('yesterday_at_time', [timeStr])` | Novo: `"yesterday_at_time": "Ontem às %s"` |
| 24 | `'$date às $timeStr'` | `t('date_at_time', [date, timeStr])` | Novo: `"date_at_time": "%s às %s"` |
| 63 | `'TOMADO'` | `t('status_taken').toUpperCase()` | Reutilizar `status_taken` |
| 65 | `'FORA DE HORA'` | `t('status_taken_late')` | Novo: `"status_taken_late": "FORA DE HORA"` |
| 67 | `'SOB DEMANDA'` | `t('status_prn_caps')` | Novo: `"status_prn_caps": "SOB DEMANDA"` |
| 69 | `'CONCLUÍDO'` | `t('status_completed_caps')` | Novo: `"status_completed_caps": "CONCLUÍDO"` |
| 71 | `'PERDIDO'` | `t('status_missed_caps')` | Novo: `"status_missed_caps": "PERDIDO"` |
| 73 | `'ADIADO'` | `t('status_snoozed_caps')` | Novo: `"status_snoozed_caps": "ADIADO"` |
| 102 | `'Histórico & Logs'` | `t('history_logs_title')` | Novo: `"history_logs_title": "Histórico & Logs"` |
| 107 | `'Eventos'` | `t('history_tab_events')` | Novo: `"history_tab_events": "Eventos"` |
| 108 | `'Logs do Sistema'` | `t('logs_title')` | Já existe no JSON |
| 133 | `'Nenhum evento registrado ainda.'` | `t('history_no_events')` | Novo: `"history_no_events": "Nenhum evento registrado ainda."` |
| 149 | `'${events.length} eventos registrados'` | `t('history_events_count', [events.length])` | Novo: `"history_events_count": "%d eventos registrados"` |
| 155, 281 | `'Limpar'` | `t('btn_clear')` | Novo: `"btn_clear": "Limpar"` |
| 160 | `'Limpar Histórico'` | `t('dialog_clear_history_title')` | Novo: `"dialog_clear_history_title": "Limpar Histórico"` |
| 161 | `'Deseja mesmo apagar todo o histórico de eventos?'` | `t('dialog_clear_history_desc')` | Novo: `"dialog_clear_history_desc": "Deseja mesmo apagar todo o histórico de eventos?"` |
| 165, 291 | `'CANCELAR'` | `t('cancel_btn').toUpperCase()` | Reutilizar |
| 169, 295 | `'LIMPAR'` | `t('btn_clear_caps')` | Novo: `"btn_clear_caps": "LIMPAR"` |
| 191 | `'Alarme'` / `'Lembrete'` | `event.type == 'alarm' ? t('fab_alarm') : t('fab_reminder')` | Já existem no JSON |
| 204 | `'Evento'` | `t('history_default_event')` | Novo: `"history_default_event": "Evento"` |
| 212 | `'Dose: ${event.dosage}'` | `t('dose_label_fmt', [event.dosage])` | Novo: `"dose_label_fmt": "Dose: %s"` |
| 259 | `'Nenhum log gerado ainda.'` | `t('logs_empty')` | Novo: `"logs_empty": "Nenhum log gerado ainda."` |
| 275 | `'${logs.length} logs registrados'` | `t('logs_count_fmt', [logs.length])` | Novo: `"logs_count_fmt": "%d logs registrados"` |
| 286 | `'Limpar Logs'` | `t('dialog_clear_logs_title')` | Novo: `"dialog_clear_logs_title": "Limpar Logs"` |
| 287 | `'Deseja mesmo apagar todos os logs de depuração?'` | `t('dialog_clear_logs_desc')` | Novo: `"dialog_clear_logs_desc": "Deseja mesmo apagar todos os logs de depuração?"` |

---

## 5. Settings Feature

### 5.1 Settings Screen (`lib/features/settings/presentation/settings_screen.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 141 | `'Nome do paciente salvo!'` | `t('settings_patient_saved_toast')` | Novo: `"settings_patient_saved_toast": "Nome do paciente salvo!"` |
| 168 | `'Backup de teste carregado...'` | `t('settings_fixture_loaded_toast')` | Novo: `"settings_fixture_loaded_toast": "Backup de teste carregado com 25 alarmes, 6 lembretes e medicamentos! 🎉"` |
| 177 | `'Erro ao carregar fixture: $e'` | `t('settings_fixture_error', [error])` | Novo: `"settings_fixture_error": "Erro ao carregar fixture: %s"` |
| 209 | `'Backup salvo com sucesso!'` | `t('settings_backup_success_toast')` | Novo: `"settings_backup_success_toast": "Backup salvo com sucesso!"` |
| 227 | `'Erro ao exportar backup: $e'` | `t('settings_backup_error', [error])` | Novo: `"settings_backup_error": "Erro ao exportar backup: %s"` |
| 251 | `'Arquivo de backup inválido ou vazio.'` | `t('settings_backup_invalid_toast')` | Novo: `"settings_backup_invalid_toast": "Arquivo de backup inválido ou vazio."` |
| 287 | `'Restaurando dados no dispositivo...'` | `t('settings_backup_restoring_toast')` | Novo: `"settings_backup_restoring_toast": "Restaurando dados no dispositivo..."` |
| 310 | `'Restauração concluída!...'` | `t('settings_backup_restore_success_toast', [count])` | Novo: `"settings_backup_restore_success_toast": "Restauração concluída! %d itens processados."` |
| 318 | `'Erro ao restaurar backup: $e'` | `t('settings_backup_restore_error', [error])` | Novo: `"settings_backup_restore_error": "Erro ao restaurar backup: %s"` |
| 373 | `'Configurações'` | `t('settings_title')` | Já existe no JSON |
| 462 | `'Erro ao carregar configurações: $err'` | `t('settings_load_error', [error])` | Novo: `"settings_load_error": "Erro ao carregar configurações: %s"` |
| 505 | `'Salvar Nome'` | `t('patient_save_btn')` | Já existe no JSON |
| 529 | `'Silencia ou ajusta notificações...'` | `t('settings_sleep_routine_desc')` | Novo: `"settings_sleep_routine_desc": "Silencia ou ajusta notificações de alarmes durante o sono"` |
| 543 | `'Dormir'` | `t('settings_sleep_time_label')` | Novo: `"settings_sleep_time_label": "Dormir"` |
| 556 | `'Acordar'` | `t('settings_wake_time_label')` | Novo: `"settings_wake_time_label": "Acordar"` |
| 585 | `'Café da Manhã'` | `t('setup_breakfast_label')` | Novo: `"setup_breakfast_label": "Café da Manhã"` |
| 598 | `'Almoço'` | `t('setup_lunch_label')` | Novo: `"setup_lunch_label": "Almoço"` |
| 611 | `'Jantar'` | `t('setup_dinner_label')` | Novo: `"setup_dinner_label": "Jantar"` |
| 645-647 | `'Português'`, `'English'`, `'Español'` | `t('lang_pt')`, `t('lang_en')`, `t('lang_es')` | Novos: `"lang_pt": "Português"`, `"lang_en": "English"`, `"lang_es": "Español"` |
| 776 | `'Rede Wi-Fi da Caixinha'` | `t('settings_wifi_section_title')` | Novo: `"settings_wifi_section_title": "Rede Wi-Fi da Caixinha"` |
| 777 | `'Gerencie as conexões de rede...'` | `t('settings_wifi_section_subtitle')` | Novo: `"settings_wifi_section_subtitle": "Gerencie as conexões de rede do dispositivo"` |
| 787 | `'Redes Salvas'` | `t('settings_wifi_saved_title')` | Novo: `"settings_wifi_saved_title": "Redes Salvas"` |
| 796 | `'Nenhuma rede Wi-Fi salva...'` | `t('settings_wifi_no_networks')` | Novo: `"settings_wifi_no_networks": "Nenhuma rede Wi-Fi salva no dispositivo"` |
| 817 | `'Esquecer Rede'` | `t('dialog_forget_network_title')` | Novo: `"dialog_forget_network_title": "Esquecer Rede"` |
| 818 | `'Tem certeza que deseja remover a rede...'` | `t('dialog_forget_network_desc', [ssid])` | Novo: `"dialog_forget_network_desc": "Tem certeza que deseja remover a rede \"%s\"?"` |
| 822 | `'Cancelar'` | `t('cancel_btn')` | Já existe no JSON |
| 826 | `'Remover'` | `t('btn_remove')` | Novo: `"btn_remove": "Remover"` |
| 837 | `'Rede removida com sucesso!'` | `t('settings_wifi_removed_toast')` | Novo: `"settings_wifi_removed_toast": "Rede removida com sucesso!"` |
| 848 | `'Erro ao carregar redes salvas: $err'` | `t('settings_wifi_load_error', [error])` | Novo: `"settings_wifi_load_error": "Erro ao carregar redes salvas: %s"` |
| 853 | `'Adicionar Nova Rede'` | `t('settings_wifi_add_title')` | Novo: `"settings_wifi_add_title": "Adicionar Nova Rede"` |
| 865 | `'Nome da Rede (SSID)'` | `t('wifi_ssid_label')` | Já existe no JSON |
| 875 | `'Senha'` | `t('wifi_pass_label')` | Já existe no JSON |
| 1467, 1475| `'Refazer Configuração Inicial'` | `t('settings_relaunch_wizard_title')` | Novo: `"settings_relaunch_wizard_title": "Refazer Configuração Inicial"` |
| 1468 | `'Reinicia o fluxo de onboarding...'` | `t('settings_relaunch_wizard_desc')` | Novo: `"settings_relaunch_wizard_desc": "Reinicia o fluxo de onboarding e pareamento local"` |
| 1476 | `'Isso desconectará a caixinha atual...'` | `t('settings_relaunch_wizard_confirm')` | Novo: `"settings_relaunch_wizard_confirm": "Isso desconectará a caixinha atual e reiniciará o assistente de onboarding. Continuar?"` |
| 1484 | `'Continuar'` | `t('btn_continue')` | Novo: `"btn_continue": "Continuar"` |
| 1505 | `'Baixar Backup do Dispositivo'` | `t('settings_download_backup_title')` | Novo: `"settings_download_backup_title": "Baixar Backup do Dispositivo"` |
| 1506 | `'Exporta as configurações...'` | `t('settings_download_backup_desc')` | Novo: `"settings_download_backup_desc": "Exporta as configurações e dados para um arquivo JSON"` |
| 1514 | `'Restaurar Backup'` | `t('backup_restore')` | Já existe no JSON (`"backup_restore": "Restaurar Backup"`) |
| 1515 | `'Importa configurações... salvou'` | `t('settings_restore_backup_desc')` | Novo: `"settings_restore_backup_desc": "Importa configurações e dados de um arquivo JSON salvo"` |
| 1523 | `'Reset de Dados'` | `t('settings_reset_data_title')` | Novo: `"settings_reset_data_title": "Reset de Dados"` |
| 1524 | `'Apaga partições específicas...'` | `t('settings_reset_data_desc')` | Novo: `"settings_reset_data_desc": "Apaga partições específicas ou restaura o padrão de fábrica"` |
| 1546 | `'Executando reset...'` | `t('reset_progress')` | Já existe no JSON (`"reset_progress": "Executando reset..."`) |
| 1568 | `'Reset efetuado!\nReiniciando caixinha...'` | `t('settings_reset_rebooting')` | Novo: `"settings_reset_rebooting": "Reset efetuado!\nReiniciando caixinha..."` |
| 1571 | `'Dados apagados com sucesso!'` | `t('reset_success')` | Já existe no JSON (`"reset_success": "Reset executado com sucesso!"`) |
| 1581, 1589| `'Reiniciar Caixinha'` | `t('settings_reboot_device_title')` | Novo: `"settings_reboot_device_title": "Reiniciar Caixinha"` |
| 1582 | `'Executa uma reinicialização...'` | `t('settings_reboot_device_desc')` | Novo: `"settings_reboot_device_desc": "Executa uma reinicialização física da MediCaixa"` |
| 1590 | `'Deseja realmente reiniciar...'` | `t('settings_reboot_device_confirm')` | Novo: `"settings_reboot_device_confirm": "Deseja realmente reiniciar a caixinha MediCaixa?"` |
| 1598 | `'Reiniciar'` | `t('btn_reboot')` | Novo: `"btn_reboot": "Reiniciar"` |

### 5.2 Device Reset Dialog (`lib/features/settings/presentation/settings_screen.dart` - `_DeviceResetDialog`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 1852 | `'Resetar Medicaixa'` | `t('reset_modal_title')` | Já existe no JSON (`"reset_modal_title": "Confirmar Reset"`) |
| 1860-1861 | `'Atenção! Esta ação apagará...'` | `t('reset_modal_desc')` | Já existe no JSON |
| 1867 | `'RESET DE FÁBRICA (Tudo)'` | `t('reset_factory_label')` | Já existe no JSON |
| 1874 | `_getPartitionLabel(key)` | `t('reset_${key}_label')` | Mapeado diretamente para as chaves `reset_alarms_label`, `reset_reminders_label`, etc. do JSON. |
| 1889 | `'Digite APAGAR abaixo para...'` | `t('reset_modal_confirm_phrase')` | Já existe no JSON (aceita marcação) |
| 1895 | `'Digite APAGAR'` | `'Digite ' + t('reset_modal_confirm_word')` | Já existe no JSON |
| 1908 | `'Cancelar'` | `t('cancel_btn')` | Já existe no JSON |
| 1921 | `'Confirmar e Apagar'` | `t('reset_btn')` | Já existe no JSON (`"reset_btn": "Resetar Selecionados"`) ou criar similar |

---

## 6. Modals

### 6.1 Snooze Modal (`lib/features/alarms/presentation/snooze_modal.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 138 | `'Gerenciar Alarme'` | `t('alarm_manage_title')` | Já existe no JSON |
| 201 | `'Desativar Alarme'` / `'Ativar Alarme'` | `widget.alarm.enabled ? t('deactivate_alarm') : t('activate_alarm')` | Já existem no JSON |
| 234 | `'Tomei'` | `t('mark_taken_btn')` | Já existe no JSON (`"mark_taken_btn": "Tomado"`) ou criar `"btn_taken": "Tomei"` |
| 253 | `'Pular'` | `t('mark_not_taken_btn')` | Já existe no JSON (`"mark_not_taken_btn": "Não Tomado"`) ou criar `"btn_skip": "Pular"` |
| 276 | `'Medicamento com Dose Dinâmica...'` | `t('alarm_dynamic_dose_info')` | Novo: `"alarm_dynamic_dose_info": "Medicamento com Dose Dinâmica (Glicose / Insulina)"` |
| 288 | `'Dose a tomar: '` | `t('dose_to_take_label')` | Novo: `"dose_to_take_label": "Dose a tomar: "` |
| 329 | `'Adiar por:'` | `t('snooze_for_label')` | Novo: `"snooze_for_label": "Adiar por:"` |
| 369 | `'minutos'` | `t('minutes_label')` | Novo: `"minutes_label": "minutos"` |
| 390 | `'Adiar'` | `t('btn_snooze')` | Novo: `"btn_snooze": "Adiar"` |
| 412 | `'Cancelar Soneca'` | `t('btn_cancel_snooze')` | Novo: `"btn_cancel_snooze": "Cancelar Soneca"` |
| 442, 488 | `'Editar'` / `'Excluir'` | `t('btn_edit')` / `t('btn_delete')` | Novos: `"btn_edit": "Editar"`, `"btn_delete": "Excluir"` |
| 454 | `'Excluir Alarme'` | `t('dialog_delete_alarm_title')` | Novo: `"dialog_delete_alarm_title": "Excluir Alarme"` |
| 456 | `'Tem certeza que deseja excluir...'` | `t('dialog_delete_alarm_desc', [name])` | Novo: `"dialog_delete_alarm_desc": "Tem certeza que deseja excluir \"%s\"?"` |

### 6.2 Reminder Action Modal (`lib/features/reminders/presentation/widgets/reminder_action_modal.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 71 | `'Gerenciar Lembrete'` | `t('reminder_manage_title')` | Novo: `"reminder_manage_title": "Gerenciar Lembrete"` |
| 141 | `'Marcar como Feito'` | `t('btn_mark_done')` | Novo: `"btn_mark_done": "Marcar como Feito"` |
| 153 | `'Concluído hoje'` | `t('reminder_completed_today')` | Novo: `"reminder_completed_today": "Concluído hoje"` |
| 199, 271 | `'Editar'` / `'Excluir'` | `t('btn_edit')` / `t('btn_delete')` | Reutilizar chaves sugeridas |
| 215 | `'Excluir Lembrete'` | `t('dialog_delete_reminder_title')` | Novo: `"dialog_delete_reminder_title": "Excluir Lembrete"` |
| 221 | `'Tem certeza que deseja excluir...'` | `t('dialog_delete_reminder_desc', [title])` | Novo: `"dialog_delete_reminder_desc": "Tem certeza que deseja excluir \"%s\"?"` |

### 6.3 Dynamic Dose Dialog (`lib/features/alarms/presentation/widgets/dynamic_dose_dialog.dart`)

| Linha | String Original | Chave Recomendada | Observação / Novo Cadastro |
|---|---|---|---|
| 165 | `'Se a $_parameterName for menor...'` | `t('dynamic_rule_less', [param, val, qty, unit])` | Novo: `"dynamic_rule_less": "Se a %s for menor que %s: tomar %s %s"` |
| 167 | `'Se a $_parameterName for maior...'` | `t('dynamic_rule_greater', [param, val, qty, unit])` | Novo: `"dynamic_rule_greater": "Se a %s for maior que %s: tomar %s %s"` |
| 169 | `'Se a $_parameterName estiver entre...'` | `t('dynamic_rule_between', [param, val1, val2, qty, unit])` | Novo: `"dynamic_rule_between": "Se a %s estiver entre %s e %s: tomar %s %s"` |
| 180 | `'Dose Dinâmica (Escala Móvel)'` | `t('dynamic_dose_title')` | Novo: `"dynamic_dose_title": "Dose Dinâmica (Escala Móvel)"` |
| 189 | `'Medicamento: ${widget.alarm.name}'` | `t('medication_label_fmt', [name])` | Novo: `"medication_label_fmt": "Medicamento: %s"` |
| 197 | `'Tabela de Dosagem:'` | `t('dosage_table_label')` | Novo: `"dosage_table_label": "Tabela de Dosagem:"` |
| 232 | `'Valor medido de $_parameterName:'` | `t('measured_value_label', [param])` | Novo: `"measured_value_label": "Valor medido de %s:"` |
| 241 | `'Digite o valor medido (ex: 165)'` | `t('enter_measured_value_hint')` | Novo: `"enter_measured_value_hint": "Digite o valor medido (ex: 165)"` |
| 259 | `'Dose a registrar:'` | `t('dose_to_register_label')` | Novo: `"dose_to_register_label": "Dose a registrar:"` |
| 271 | `'Dose final'` | `t('final_dose_hint')` | Novo: `"final_dose_hint": "Dose final"` |
| 298 | `'Cancelar'` | `t('cancel_btn')` | Já existe no JSON |
| 305 | `'Por favor, insira uma dose válida...'` | `t('invalid_dose_msg')` | Novo: `"invalid_dose_msg": "Por favor, insira uma dose válida maior que 0."` |
| 316 | `'Confirmar Dose'` | `t('confirm_dose_btn')` | Novo: `"confirm_dose_btn": "Confirmar Dose"` |
