# Original User Request

## 2026-06-28T14:06:38Z

<USER_REQUEST>
Reorganizar a aba de Ajustes do aplicativo Flutter para separar claramente as configurações locais (Offline-First) das configurações físicas da caixinha (MediCaixa). Implementar todas as integrações de rede e hardware que estão ausentes comparando com o projeto C++ (Wi-Fi, Toques de Som, Sincronização de Relógio, Status de Pareamento de Voz, Backup/Restore e Reset de dados do dispositivo).

Working directory: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app
Integrity mode: development

## Requirements

### R1. Separação de Ajustes Locais vs. Dispositivo
O aplicativo deve separar visualmente as configurações locais do próprio aplicativo (Idioma do App, Nome do Paciente, Atalho de Medicamentos, Opções de Desenvolvedor) dos ajustes físicos da caixinha.
- Quando o aplicativo estiver em modo **Standalone** (desconectado), a seção de Ajustes da Caixinha deve ser exibida em um estado desabilitado (menor opacidade/cinza) com um cartão informativo amigável explicando que é necessária a conexão física para gerenciar os recursos.
- Quando estiver em modo **Conectado**, a seção de Ajustes da Caixinha fica totalmente ativa e interativa.

### R2. Gerenciamento de Wi-Fi da Caixinha
Implementar a interface de Wi-Fi para o dispositivo conectado:
- Buscar redes disponíveis no dispositivo (`GET /wifi_scan`), ordená-las por intensidade de sinal (RSSI) e exibir a lista com ícone de cadeado se protegida e barras de sinal. Tocar em uma rede preenche o campo de SSID.
- Exibir a lista de redes salvas no dispositivo (`GET /wifi_list`) com opção de excluir/esquecer uma rede (`POST /wifi_remove` com payload `{"ssid": "..."}`).
- Formulário para adicionar nova rede manual ou via rede escaneada (`POST /wifi_add` com payload `{"ssid": "...", "password": "..."}`).

### R3. Configuração de Som e Ajustes de Hardware
Integrar os controles de áudio e tela da caixinha:
- Volume do alto-falante (`speaker_volume`) e brilho do display OLED (`brightness`) devem ser integrados à seção da caixinha.
- Seletor de Toque do Alarme (Gentil, Alerta, Melodia, Urgente, Musical) e seletor de Intervalo de repetição (1s, 3s, 6s, 10s) salvando no dispositivo (`POST /save_settings`).
- Botão "Testar Som" que chama (`POST /test_sound`) com o índice do toque escolhido para reproduzir áudio imediato na caixinha.

### R4. Sincronização do Relógio (RTC)
Exibir o horário atual do relógio interno da caixinha (`GET /server_time` formatado em data e hora).
- Botão "Sincronizar com Celular" para obter o horário atual do telefone e enviar para a caixinha (`POST /set_datetime` com payload contendo `year`, `month`, `day`, `hour`, `minute`, `second`).
- Botão para ajuste manual de data/hora abrindo pickers do Flutter e enviando o mesmo payload para o endpoint.

### R5. Assistente de Voz Xiaozhi (IA)
Implementar monitoramento do assistente de voz da caixinha:
- Consultar periodicamente (`GET /voice_status`) ou sob demanda o estado atual do assistente de voz.
- Exibir o estado da voz com um indicador colorido (ponto de status e texto) correspondente aos estados: desconectado (cinza), conectando (amarelo), conectado (verde), ouvindo (azul), pensando (roxo), falando (ciano) ou erro (vermelho).
- Se a resposta contiver um `activation_code` não-vazio, exibir a área e o cartão com o código em destaque instruindo o usuário a parear o dispositivo no site `xiaozhi.me`.

### R6. Manutenção do Dispositivo (Backup, Restore, Reset)
Implementar ações de manutenção na caixinha:
- **Refazer Configuração Inicial**: Botão para reiniciar o fluxo de onboarding no dispositivo.
- **Backup**: Permitir o download do arquivo de backup do dispositivo (`GET /backup`) para a memória local do celular/desktop.
- **Restaurar Backup**: Selecionar um arquivo JSON local, abrir um modal de seleção onde o usuário escolhe quais dados quer restaurar (meds, alarms, reminders, history, wifi, settings, xiaozhi, chat, logs) e enviar via `POST /restore` apenas as chaves filtradas selecionadas. Se a restauração requerer reinício, mostrar overlay de progresso do reinício da caixinha.
- **Reset de Dados**: Abrir um modal de confirmação. Permitir selecionar quais partições resetar (ou reset de fábrica total) e exigir que o usuário digite a palavra "APAGAR" em letras maiúsculas para executar o comando (`POST /reset`).

## Acceptance Criteria

### Interface Visual (UI)
- [ ] Aba Ajustes exibe seção "Ajustes do Aplicativo" sempre disponível.
- [ ] Seção "Ajustes da Caixinha" fica desabilitada e exibe card informativo sobre pareamento quando desconectado.
- [ ] Seção "Ajustes da Caixinha" fica ativa quando conectado e apresenta controles organizados em ExpansionTiles ou Cards expansíveis.
- [ ] Diálogo de confirmação de reset exibe seleção de partições e validação exata da palavra "APAGAR".
- [ ] Diálogo de restauração lê o JSON do backup local e permite selecionar chaves antes do envio.

### Funcionalidade e Integração API
- [ ] Busca de Wi-Fi (`/wifi_scan`) lista as redes com ordenação de RSSI e toque para preencher SSID.
- [ ] Exclusão de rede Wi-Fi chama `/wifi_remove` e atualiza a lista de redes salvas (`/wifi_list`).
- [ ] Sincronização do relógio envia com sucesso a data/hora local ou manual para `/set_datetime`.
- [ ] Controle de som altera o toque no dispositivo (`/save_settings`) e "Testar Som" dispara `/test_sound`.
- [ ] O status da voz exibe corretamente o ponto colorido baseado no JSON de `/voice_status`.
- [ ] Backup baixa o arquivo da caixinha e a Restauração envia as chaves selecionadas para o `/restore`.
- [ ] O Reset de dados envia a chamada de `/reset` com as flags configuradas pelo usuário.

</USER_REQUEST>

## 2026-06-28T14:13:22Z

<USER_REQUEST>
Milestone 2: Settings & C++ Box Integrations.
Your task is to implement the Settings reorganization and C++ box integrations in the Flutter application following the designs detailed in:
- UI Layout design: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/explorer/settings_ui_design.md
- Wifi & Sound design: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/explorer/wifi_sound_design.md
- Clock, Voice & Maintenance design: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/explorer/findings_m2.md

### Core Responsibilities:
1. Reorganize 'lib/features/settings/presentation/settings_screen.dart':
   - Split local settings (Nome do Paciente, Idioma do App, Cadastro de Medicamentos, Opções de Desenvolvedor) from physical device settings (volume/brightness, Wi-Fi, sound melodies, RTC clock sync, voice assistant, maintenance).
   - Implement Connection Guard: when disconnected/standalone (pairingNotifierProvider.status != ConnectionStatus.connected), show a warning alert card explaining connection is needed, and wrap device settings in an Opacity(opacity: 0.55) and IgnorePointer(ignoring: true) container.
2. Wi-Fi Management:
   - Create model 'WifiNetwork', 'WifiRepository', and Riverpod providers in 'lib/features/settings/data/wifi_repository.dart'.
   - Scanned networks (GET /wifi_scan) sorted by RSSI descending, locked icon if secure. Tap pre-fills SSID.
   - Saved networks list (GET /wifi_list) with delete/remove button (POST /wifi_remove).
   - Add new network form (manual/scanned SSID + password) posting to /wifi_add.
3. Sound & Screen Brightness:
   - Save volume and brightness to device.
   - Ringtone selector (Gentil, Alerta, Melodia, Urgente, Musical) and repeat interval dropdown (1s, 3s, 6s, 10s -> mapping to 'alarmSpacingMs') saving via POST /save_settings.
   - 'Testar Som' button calling POST /test_sound with chosen ringtone index.
4. Clock Sync (RTC):
   - Display current time from GET /server_time.
   - 'Sincronizar Celular' button sending current system time to POST /set_datetime.
   - Manual picker button opening Flutter date & time pickers and sending combined date/time to POST /set_datetime.
5. Voice Assistant Monitor:
   - Periodically check GET /voice_status (e.g. using a StreamProvider or periodic fetch).
   - Display state using a color status dot (disconnected: grey, connecting: yellow, connected: green, listening: blue, thinking: purple, speaking: cyan, error: red) and localized label.
   - If 'activation_code' is not empty, display it inside an activation card with clipboard copy option.
   - Wake word dropdown and Gemini API Key textfield.
6. Device Maintenance:
   - "Refazer Configuração Inicial" button resetting local state, wiping IP, calling disconnect, and re-routing to pairing screen.
   - "Backup": fetch GET /backup JSON, handle download (using file_picker to save on macOS, share_plus on mobile).
   - "Restaurar Backup": choose JSON, select checkboxes for keys to restore, post to /restore, and reboot ESP32 with progress indicator if reboot is required.
   - "Reset de Dados": confirmation dialog, select partitions to wipe, force user to type "APAGAR" to execute POST /reset, reboot ESP32 with progress indicator if reboot is required.
7. Run code generation: 'dart run build_runner build --delete-conflicting-outputs' (or flutter equivalent) to generate the required '.g.dart' files.
8. Verify the project builds and runs cleanly without analyzer errors: 'flutter analyze'.

### Constraints:
- Do not use 'const' with AppColors. Icon, TextStyle, BorderSide, etc. referencing AppColors.xxx must NOT be const.
- Follow drift database naming conventions and keep offline-first database.
- Use context.mounted in asynchronous operations to prevent memory leaks/lint errors.
- Never write relative imports in new files; use package imports, or use the flutter-import-verification skill to double-check.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
</USER_REQUEST>

## 2026-06-28T14:19:05Z

<USER_REQUEST>
Milestone 2: Settings & C++ Box Integrations.
Review the data layer changes in 'lib/features/settings/data/wifi_repository.dart', 'settings_repository.dart', and 'settings_models.dart'. Ensure correct endpoint integrations (/wifi_scan, /wifi_list, /wifi_add, /wifi_remove, /server_time, /set_datetime, /voice_status, /backup, /restore, /reset, /restart, /test_sound). Verify sequential serialization of requests, proper handling of optional fields, and offline-first compliance. Run 'flutter analyze' and 'flutter test' to verify data integrity. Report your findings.
</USER_REQUEST>

## 2026-06-28T14:34:16Z

<USER_REQUEST>
Remediation for Settings UI Violations (Rule 22 & Rule 32).
Your task is to fix the static review findings identified in 'lib/features/settings/presentation/settings_screen.dart':

1. SnackBar / AppColors Violation (Rule 22):
   Remove the 'const' keyword from any SnackBar initialization that references AppColors (such as AppColors.success or AppColors.missed). For example:
   - Line 859: const SnackBar(content: Text('Rede removida com sucesso!'), ...
   - Line 927: const SnackBar(content: Text('Rede Wi-Fi salva com sucesso!'), ...
   - Line 1199: const SnackBar(content: Text('Relógio sincronizado com o celular!'), ...
   - Line 1254: const SnackBar(content: Text('Horário manual enviado com sucesso!'), ...
   Change these SnackBar initializations to not use 'const'.

2. Context Mounted Violation (Rule 32):
   Verify all asynchronous callbacks and replace checks of 'if (mounted)' with 'if (context.mounted)' before interacting with BuildContext (such as showing a SnackBar or navigating). Check specifically:
   - Line 139: if (mounted) { ScaffoldMessenger.of(context).showSnackBar(...
   - Line 164 & 173: if (mounted) { ScaffoldMessenger.of(context).showSnackBar(...
   - Line 925: if (mounted) { ScaffoldMessenger.of(context).showSnackBar(...
   - Line 1197: if (mounted) { ScaffoldMessenger.of(context).showSnackBar(...
   - Line 1252: if (mounted) { ScaffoldMessenger.of(context).showSnackBar(...
   Ensure all of these are replaced with 'if (context.mounted)'.

3. Verification:
   Run 'flutter analyze' to verify that no compilation errors remain, and run 'flutter test' to verify that the tests continue to pass.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
</USER_REQUEST>

## 2026-06-28T15:25:05Z

<USER_REQUEST>
Criar a tela de Relatórios (`ReportsScreen`) no Flutter baseada nos gráficos de adesão e mapa de calor do projeto C++ (Xiaozhi). Alterar a aba principal "Relatórios" no menu inferior para abrir esta nova tela, enquanto o botão "Histórico & Logs" da tela de Início (Dashboard) continuará abrindo a listagem detalhada de logs (`HistoryScreen`).

Working directory: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app
Integrity mode: development

## Requirements

### R1. Tela de Relatórios (`ReportsScreen`) e Nova Aba
Substituir a terceira aba do menu inferior (`AppShell`) da classe `HistoryScreen` para a nova `ReportsScreen`.
- A tela deve exibir o cabeçalho "Relatórios" / "Análise de Medicamentos".
- A tela deve ser composta por uma grade/lista vertical de cartões de gráficos e uma barra horizontal de chips de filtro no rodapé (fiel ao C++).
- A barra de chips de filtro conterá a opção "Todos" e chips para cada medicamento cadastrado no app, exibindo um ponto colorido e o nome do remédio. Tocar em um chip filtra todos os gráficos para as métricas daquele medicamento específico.

### R2. Gráficos de Adesão usando CustomPainter (Fidelidade Visual 100%)
Todos os gráficos devem ser desenhados sob medida usando `CustomPainter` do Flutter para garantir cantos arredondados, cores exatas e layout idêntico ao C++, sem instalar novos pacotes:
1. **Adesão Geral (Donut Chart)**: Gráfico de donut dividido em seções coloridas: Verde (`#10b981` para Tomados), Vermelho (`#ef4444` para Perdidos), Laranja (`#f59e0b` para Pulados/Cancelados/Adiados). Exibir a porcentagem média de adesão no centro em tamanho grande e a legenda ao lado com a contagem de tomados, perdidos e pulados.
2. **Adesão Diária (Daily Bars)**: 7 colunas verticais representando os últimos 7 dias (incluindo hoje). Cada coluna deve ter um track cinza e uma barra preenchida proporcional à porcentagem de adesão do dia (mínimo de 10% se houver alarmes esperados). A cor da barra segue o padrão: Verde (>=80%), Laranja (>=50%), Vermelho (<50%) ou transparente (sem alarmes esperados). Exibir a porcentagem em texto e o rótulo do dia (SEG, TER, etc.).
3. **Sequência (Streak)**: Exibe a sequência atual ("N dias seguidos") e a melhor sequência histórica ("Melhor: N dias seguidos"). Ao lado, exibir a grade de 14 bolinhas (2x7) representando o histórico dos últimos 14 dias: Verde (completo), Laranja (parcial), Vermelho (perdido) ou cinza/vazio.
4. **Por Horário (Period Distribution)**: 3 colunas representando Manhã (00:00-11:59), Tarde (12:00-17:59), Noite (18:00-23:59). Cada uma exibe seu ícone representativo (Sol, Sol/Nuvem, Lua), rótulo, barra de progresso vertical e fração de adesão (ex: 47/67).

### R3. Gráfico "Por Medicamento"
Uma listagem horizontal de barras de progresso (somente exibida quando o filtro selecionado for "Todos").
- Mostra cada medicamento ativo.
- A barra horizontal deve ser preenchida de acordo com a porcentagem de adesão do medicamento e colorida com a cor correspondente do cadastro do remédio.

### R4. Mapa Mensal (Monthly Heatmap)
Grade estilo calendário de 5 semanas exibindo os últimos 30 dias.
- Cada célula exibe o número do dia e é colorida de acordo com a adesão do dia:
  - Sem dados / Futuro: Cinza escuro (`#1e293b`).
  - Adesão 100%: Verde esmeralda.
  - Adesão 75%-99%: Verde claro.
  - Adesão 50%-74%: Amarelo.
  - Adesão 25%-49%: Laranja.
  - Adesão <25%: Vermelho.
- Legenda no rodapé indicando os níveis de 0% a 100% e caixa de "Sem dados".

### R5. Lógica e Fórmulas de Adesão (Fiel ao C++)
Os gráficos devem calcular as métricas consultando a tabela local `history_events` do Drift SQLite seguindo rigorosamente a lógica do projeto C++ (referenciada em `index.html`).
- Um evento conta como "Tomado" (taken) se o status for `TOMADO`, `TOMADO FORA HORA`, `TOMADO PRN` ou `CONCLUIDO`.
- Conta como "Não Tomado" (missed) se o status for `PERDIDO`.
- Conta como "Cancelado" (skipped) se o status for `PULADO`, `CANCELADO` ou `SNOOZED`.
- O cálculo da sequência de dias deve analisar os últimos 30 dias retrospectivamente a partir de hoje: dias sem alarmes cadastrados não quebram a sequência, apenas dias com alarmes que tiveram falhas (missed > 0).

## Acceptance Criteria

### Interface Visual (UI)
- [ ] A aba "Relatórios" do menu inferior abre o `ReportsScreen` contendo os novos gráficos, sem abas de logs.
- [ ] Os gráficos de Donut, Barras Diárias, Sequência e Mapa de Calor são renderizados usando `CustomPainter` com cantos arredondados, gradientes e cores fiéis aos protótipos C++.
- [ ] O filtro horizontal de chips de medicamentos é exibido no rodapé do `ReportsScreen`. Tocar em um chip filtra todos os gráficos e oculta o card "Por Medicamento".
- [ ] O botão "Histórico & Logs" no topo do Dashboard continua abrindo a tela `HistoryScreen` com as abas originais de logs e eventos.

### Funcionalidade e Lógica
- [ ] O cálculo de adesão (Donut e Barras Diárias) lê as datas corretas e faz a proporção exata de doses tomadas / totais esperadas.
- **Normalização de datas**: O cálculo de dias do Mapa Mensal e das Barras Diárias funciona corretamente no fuso horário local e normaliza as datas para evitar fuso horário quebrado.
- [ ] A sequência de dias (Streak) calcula a sequência atual e a melhor sequência com base nas regras C++ (ignorando dias sem alarmes programados).
- [ ] O teste de análise estática `flutter analyze` compila com 0 erros.

## 2026-06-28T17:12:01Z

<USER_REQUEST>
Implementar a janela suspensa de ações rápidas "Gerenciar Lembrete" ao clicar em um lembrete no Dashboard, substituindo a navegação direta para a tela de edição completa. A janela deve seguir o design do projeto C++ (Xiaozhi) e as práticas adotadas na gestão de alarmes no Flutter.

Working directory: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app
Integrity mode: development

## Requirements

### R1. Criação do `ReminderActionModal` (Bottom Sheet)
Criar o widget de bottom sheet `ReminderActionModal` para gerenciar lembretes (sugerido em `lib/features/reminders/presentation/widgets/reminder_action_modal.dart` ou similar):
- **Título da Janela**: Exibir "Gerenciar Lembrete" centralizado.
- **Identificação**: Exibir o ícone de alfinete (`Icons.push_pin_rounded`) com a cor do lembrete e o título do lembrete (negrito, centralizado).
- **Descrição/Subtítulo**: Se o lembrete possuir descrição, exibi-la logo abaixo do título do lembrete in fonte menor e cor cinza/muted.
- **Ação Principal (Marcar como Feito)**:
  - Se o lembrete NÃO estiver concluído hoje, exibir um botão verde de largura total com o texto "Marcar como Feito" (chamando `completeReminder` e fechando o modal).
  - Se já estiver concluído hoje, exibir o texto centralizado em verde "Concluído hoje" (ou semelhante) sem o botão.
- **Divisor**: Exibir uma linha horizontal de divisão.
- **Ações de Configuração**: Uma fileira horizontal com dois botões de largura igual:
  - **Editar**: Fecha o modal e abre a tela de edição do lembrete (`ReminderFormScreen(editReminder: reminder)`).
  - **Excluir**: Exibe um diálogo de confirmação. Se confirmado, exclui o lembrete (`deleteReminder`), fecha o modal e atualiza a tela.

### R2. Integração no Dashboard
Na tela `dashboard_screen.dart`, alterar o callback `onTap` dos cartões de lembretes para abrir o novo `ReminderActionModal`.
- Ao concluir, editar ou excluir um lembrete a partir do modal, o estado do Dashboard deve ser atualizado reativamente via `dashboardNotifierProvider`.

### R3. Testes e Análise Estática
- Escrever testes de widget para validar que tocar em um lembrete abre o modal de ações e executa "Marcar como Feito", "Editar" e "Excluir".
- Certificar-se de que a análise estática (`flutter analyze`) resulte em zero erros e avisos.

## Acceptance Criteria

### Interface Visual (UI)
- [ ] Ao clicar em um lembrete na aba Início (Dashboard), abre-se um bottom sheet intitulado "Gerenciar Lembrete".
- [ ] O modal exibe o ícone de pin colorido, o título do lembrete e a descrição (se houver).
- [ ] O botão verde "Marcar como Feito" é exibido somente se o lembrete não estiver marcado como concluído hoje. Caso contrário, exibe o texto "Concluído hoje".
- [ ] Os botões "Editar" e "Excluir" estão alinhados lado a lado na base do modal.
- [ ] O botão "Excluir" exibe uma caixa de diálogo de confirmação antes de remover o lembrete.

### Funcionalidade e Lógica
- [ ] Tocar em "Marcar como Feito" executa `completeReminder` no repositório, insere o evento no histórico e atualiza a UI.
- [ ] Tocar em "Editar" navega corretamente para a tela de edição preenchida.
- [ ] Tocar em "Excluir" and confirmar remove o registro do banco de dados local (e sincroniza se conectado).
- [ ] `flutter analyze` roda com 0 issues.
- [ ] Novos testes de unidade/widget cobrem o comportamento do modal e de suas ações com sucesso.

</USER_REQUEST>

## 2026-06-28T18:42:02Z

<USER_REQUEST>
Reorganizar o cabeçalho da tela de Início (Dashboard) para tornar fixa a área superior com nome, data, health banner e calendar strip, e implementar a funcionalidade de seções de período (Manhã, Tarde, Noite) retráteis/collapsible com contadores de alarmes e fechamento automático com base no horário (fiel ao C++) com melhorias sugeridas pelo usuário.

Working directory: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app
Integrity mode: development

## Requirements

### R1. Reorganização e Fixação do Cabeçalho do Dashboard
Alterar o layout de `dashboard_screen.dart` para que o cabeçalho fique fixado no topo do `Scaffold` (não rolando com o restante da página).
- **Ordem dos Elementos**:
  1. Header Card (Nome do paciente, data e botões rápidos de sincronização/histórico).
  2. Health Banner (`HealthBannerWidget`).
  3. Calendar Strip (`CalendarStripWidget`).
  4. Indicador de status de conexão (Offline/Conectado).
- **Rolagem**: Apenas a lista de lembretes, alarmes agrupados por período e a sidebar de Ritmo Semanal (no desktop) devem rolar verticalmente sob o cabeçalho fixo.

### R2. Seções de Período Retráteis (Collapsible) com Animação Suave
Substituir os cabeçalhos fixos de período por cabeçalhos clicáveis com chevrons discretos indicando o estado de expansão:
- **Contadores de Alarme**:
  - Exibir a quantidade de alarmes ativos da seção ao lado do título, ex: "Manhã (3)".
  - **Doses Perdidas**: Caso haja algum alarme marcado como perdido (status "Não Tomado" ou "Perdido" hoje) nessa seção, exibir a contagem de perdidos ao lado em **cor vermelha** (ex: "Manhã (3) • 1" ou semelhante), facilitando o entendimento visual imediato de doses perdidas.
- **Animação**: Usar `AnimatedSize` or `AnimatedCrossFade` para expandir e retrair o conteúdo dos cartões de forma fluida.
- **Opção de Fechamento**: Clicar em qualquer parte do cabeçalho da seção deve alternar o estado expandido/retraído.
- **Seção Vazia**: Seções sem alarmes devem exibir o placeholder *"Nenhum alarme neste período"* e permanecer sempre expandidas (sem chevron de colapso).

### R3. Lógica C++ de Auto-Colapso por Horário e Doses Pendentes
Implementar as regras de colapso automático baseado no horário e no status de doses pendentes:
- **Auto-Colapso para HOJE**:
  - Se a data selecionada for **hoje**, uma seção deve iniciar colapsada se:
    1. O período de tempo já passou:
       - A seção **Manhã** inicia retraída se a hora local atual for `>= 12`.
       - A seção **Tarde** inicia retraída se a hora local atual for `>= 18`.
       - A seção **Noite** (e Sob Demanda/PRN) nunca se auto-retrai por horário.
    2. **OU** não há mais alarmes pendentes a tomar na seção (todos os alarmes da seção para hoje já foram tomados, pulados/cancelados, suspensos, inativos ou perdidos). Isso direciona o foco do usuário para as seções com tarefas ativas pendentes.
- **Comportamento para Outros Dias**:
  - Se o usuário selecionar qualquer outra data no Calendar Strip, todas as seções de alarme devem iniciar expandidas (collapsed = false).
- **Interação Manual**: Se o usuário expandir ou retrair manualmente uma seção, o app deve respeitar a escolha do usuário até que ele altere a data selecionada ou o estado seja recarregado.

### R4. Testes e Estabilidade
- Escrever testes de widget para validar o comportamento de fixação do cabeçalho e a lógica de colapso automático (por horário e por conclusão de doses) e a exibição de contagem de perdidos em vermelho.
- Certificar-se de que a análise estática (`flutter analyze`) resulte em 0 erros e avisos.
- Garantir que todos os testes unitários e de widget passem com sucesso.

## Acceptance Criteria

### Interface Visual (UI)
- [ ] O cabeçalho contendo nome, data, Health Banner, Calendar Strip e status de conexão permanece fixo no topo da tela de início, enquanto a lista de lembretes e alarmes rola por baixo dele.
- [ ] As seções "Manhã", "Tarde" e "Noite" possuem chevrons à direita indicando o estado expandido/retraído (somente quando contêm alarmes).
- [ ] As seções exibem a contagem correta de alarmes ao lado de seus títulos, ex: "Manhã (2)".
- [ ] Se houver alarmes perdidos na seção, a quantidade de perdas é exibida em vermelho ao lado do total.
- [ ] A expansão e retração das seções ocorre através de uma animação suave de transição de tamanho.

### Funcionalidade e Lógica
- [ ] Se a data selecionada for hoje e a hora atual for `>= 12`, a seção "Manhã" inicia colapsada.
- [ ] Se a data selecionada for hoje e a hora atual for `>= 18`, a seção "Tarde" inicia colapsada.
- [ ] Se a data selecionada for hoje e todos os alarmes de uma seção já estiverem concluídos ou perdidos (sem pendências), a seção correspondente inicia colapsada.
- [ ] Ao navegar para outro dia no calendário, todas as seções de período iniciam totalmente expandidas.
- [ ] Clicar no cabeçalho inverte o estado expandido/retraído e preserves a preferência do usuário.
- [ ] `flutter analyze` reporta 0 erros.
- [ ] Testes automatizados verificam o funcionamento das seções retráteis e sua inicialização por fuso/hora.

</USER_REQUEST>

## 2026-06-28T21:20:08Z

<USER_REQUEST>
Implementar o Tema Claro (Light Theme) para o aplicativo Flutter da MediCaixa, replicando as cores e estética do projeto C++ (Xiaozhi) e adicionando o seletor de tema (Apenas "Claro" e "Escuro") na aba Ajustes com persistência local no Drift SQLite.

Working directory: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app
Integrity mode: development

## Requirements

### R1. Definição do Tema Claro (`AppColors` Dinâmico e `ThemeData`)
- Criar a especificação de cores claras em `AppColors` baseada estritamente nas variáveis CSS do projeto C++:
  - Background (Scaffold): `#f3f4f6`
  - Surface (Cards/Camadas): `#ffffff`
  - Text principal: `#1f2937`
  - Text muted (secundário): `#6b7280`
  - Border / Divider: `#e5e7eb`
  - Primary color (Verde): `#10b981` (Dark primary: `#059669`)
  - Status de saúde do Banner (Light mode):
    - Ok: Bg `#ecfdf5`, Texto/Ícone `#059669`, Borda `#6ee7b7`
    - Warn: Bg `#fefce8`, Texto/Ícone `#b45309`, Borda `#fde047`
    - Risk: Bg `#fff7ed`, Texto/Ícone `#c2410c`, Borda `#fdba74`
    - Danger: Bg `#fef2f2`, Texto/Ícone `#b91c1c`, Borda `#fca5a5`
- Para permitir que os mais de 700 widgets que usam `AppColors.xxx` estaticamente se adaptem sem quebras de compilação, transformar os campos de cor da classe `AppColors` em variáveis estáticas (`static Color`) não-finais.
- Adicionar o método `AppColors.setTheme(bool isDark)` para reatribuir essas cores em tempo real dependendo do estado do tema.

### R2. Gerenciador de Estado do Tema (Riverpod)
- Criar um provider `appThemeProvider` (Notifier) para gerenciar o estado do tema (Claro ou Escuro).
- Chamar `AppColors.setTheme(isDark)` sempre que o tema for alterado ou inicializado.
- No widget principal (`MediCaixaApp` em `app.dart`), assistir a este provider e atualizar o parâmetro `themeMode` do `MaterialApp` (`ThemeMode.light` ou `ThemeMode.dark`), definindo também a especificação completa de `lightTheme` em `AppTheme`.

### R3. Persistência de Preferência do Tema (Drift SQLite)
- Adicionar a coluna `themeMode` (ou `theme_mode`) na tabela `Settings` do Drift SQLite com valor padrão `'dark'`.
- Incrementar a `schemaVersion` do banco de dados para `5` e adicionar a migração correta (`addColumn`) no `MigrationStrategy`.
- Salvar e recuperar a preferência de tema da tabela de configurações para que ela seja mantida após reabrir o app.

### R4. Seletor de Tema na Interface (Aba Ajustes)
- Na tela `settings_screen.dart`, na seção "Ajustes Locais", adicionar uma nova linha para "Tema / Aparência" com um seletor visual (`SegmentedButton`) contendo as opções de tema "Escuro" (Dark) e "Claro" (Light).
- O seletor deve atualizar o estado do tema em tempo real e salvar a escolha no banco de dados.

### R5. Testes e Estabilidade
- Escrever testes automatizados que garantam que a troca de tema no formulário de ajustes altera a configuração de cores ativa na UI e no banco de dados.
- Certificar-se de que a análise estática (`flutter analyze`) resulte in 0 erros e avisos.

## Acceptance Criteria

### Interface Visual (UI)
- [ ] O seletor de aparência ("Aparência") é exibido nos Ajustes Locais com as opções "Claro" e "Escuro".
- [ ] Clicar em "Claro" altera instantaneamente o fundo do aplicativo para cinza claro (`#f3f4f6`), os cartões para branco (`#ffffff`), os textos para escuro (`#1f2937`) e as bordas para cinza claro (`#e5e7eb`).
- [ ] O banner de saúde e o calendar strip adaptam suas cores de status para os tons claros (Ok: `#ecfdf5`, Warn: `#fefce8`, Risk: `#fff7ed`, Danger: `#fef2f2`).

### Funcionalidade e Lógica
- [ ] O estado do tema é gerenciado via Riverpod e atualiza o `AppColors` estático dinamicamente em tempo real.
- [ ] O tema selecionado é persistido na tabela de `settings` do Drift database.
- [ ] A migração da base de dados para a versão 5 ocorre de forma limpa, inicializando o campo com `'dark'`.
- [ ] `flutter analyze` roda com 0 issues.
- [ ] Testes de widget e de unidade cobrem a alternância de tema e persistência com sucesso.
</USER_REQUEST>

## 2026-06-28T20:22:07-03:00

<USER_REQUEST>
Execução de testes funcionais, exploratórios e de interface no aplicativo Flutter MediCaixa para identificar inconsistências e bugs nas operações de CRUD de medicamentos, alarmes e lembretes, utilizando um simulador de iPhone 14 Pro Max.

Working directory: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app
Integrity mode: development

## Requirements

### R1. Execução no Simulador iOS e Inspeção Semântica/Visual
- Inicializar o simulador de iPhone 14 Pro Max (UUID `FAEFDC66-A2BD-4EE1-ADB5-9880A84CE09D`) e iniciar o app nele (`flutter run -d FAEFDC66-A2BD-4EE1-ADB5-9880A84CE09D`).
- Analisar a consistência visual da interface do usuário (UI) usando logs de console, erros de renderização (como overflows), contraste e conformidade com as regras de cores dinâmicas (sem usar cores hardcoded como branco/preto absoluto em textos/ícones).
- Verificar a conformidade do app com as regras especificadas no [AGENTS.md](file:///Users/almanimation/Downloads/Caixa%20Remedios/medicaixa_app/.agents/AGENTS.md) (como a estrutura de 4 abas, lógica do motor de alarmes, etc.).

### R2. Testes Exploratórios de Lógica e CRUD
- Testar a criação, edição e exclusão de:
  - **Medicamentos**: inclusive tentar excluir medicamentos in uso para validar se o bloqueio de exclusão funciona conforme especificado na Regra 35.
  - **Alarmes**: criar horários comuns, customizados e com frequências complexas (dias alternados, PRN, etc.) e verificar o salvamento no banco local (Drift/SQLite).
  - **Lembretes**: criar, validar a exibição ou ocultação quando vazios no Dashboard (Regra 33).
- Identificar e documentar quaisquer falhas de lógica, crashes, erros de concorrência ou loops do motor de alarmes.

### R3. Criação de Testes de Integração (Opcional/Adicional)
- Escrever testes de integração permanentes na pasta `integration_test/` ou testes de widget na pasta `test/` cobrindo pelo menos um fluxo de CRUD de alarmes ou medicamentos para garantir que regressões não ocorram.

## Verification & Deliverables

O agente deve produzir um relatório detalhado em markdown contendo:
1. **Erros e Bugs Identificados**: Lista estruturada de bugs contendo gravidade, comportamento observado, comportamento esperado (referenciando as regras do `AGENTS.md`) e como reproduzir.
2. **Resultados dos Testes de Integração**: Sucesso ou falha dos testes criados.
3. **Recomendações de Correção**: Sugestões diretas de mudanças no código para sanar cada problema encontrado.

## Acceptance Criteria

### Teste de UI e Usabilidade
- [ ] O simulador iOS foi iniciado com sucesso e o app executou nele.
- [ ] Foram verificados os layouts nas 4 abas principais do app buscando overflows e problemas de contraste/cores.
- [ ] Foi gerado um relatório de bugs encontrados estruturado.

### Testes de CRUD e Regras de Negócio
- [ ] Foi testada a exclusão de um medicamento associado a um alarme ativo (deve falhar e exibir diálogo conforme Regra 35).
- [ ] Foi criada uma rotina de teste de integração funcional executável ou suite de testes de widget para validar o fluxo principal de alarmes/medicamentos.
</USER_REQUEST>


