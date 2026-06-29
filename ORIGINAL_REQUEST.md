# Original User Request

## Initial Request — 2026-06-28T21:30:23-03:00

Correção de bugs específicos no aplicativo MediCaixa Flutter relacionados ao adiamento de alarmes disparados, overflow na modal de gerenciar alarmes, cintilação (piscada) na troca de datas do calendário do Dashboard, consistência de formato do FAB e sincronização/herança de cores entre medicamentos, alarmes e lembretes com base na paleta do projeto C++.

Working directory: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app
Integrity mode: development

## Requirements

### R1. Fechamento da Tela de Alarme ao Adiar
- Na tela de alarme disparado (alarm_active_screen.dart), ao clicar em "adiar 10 min", certifique-se de que a tela seja fechada (desempilhada da navegação), da mesma forma que acontece ao "marcar como tomado" ou "pular dose".

### R2. Correção de RenderFlex Overflow na Modal Gerenciar Alarme
- Corrigir o RenderFlex overflow de 71 pixels no bottom na modal/bottom sheet "Gerenciar Alarme" (snooze_modal.dart). 
- Utilize técnicas de layout fluido (ex: envolver os controles in um `SingleChildScrollView`, ajustar margens/paddings, ou usar `SafeArea`) para garantir compatibilidade com viewports estreitos e evitar exceções de overflow.

### R3. Prevenção de Cintilação (Piscadas) ao Trocar Dias no Calendário
- Investigar a cintilação (tela inteira piscando/sumindo e voltando) ao trocar as datas no calendário (dashboard_screen.dart).
- **Solução**: Modificar a UI do Dashboard para manter o layout visível com os dados do dia anterior (ou um placeholder sutil apenas para as seções de lista) enquanto recarrega, ou exibir uma barra de progresso discreta (como `LinearProgressIndicator` no topo) sem remover/destruir todo o Scaffold da tela quando estiver em estado de loading do Riverpod.

### R4. Consistência do Formato do FAB na Tela de Início
- No arquivo dashboard_screen.dart (linha 328), configure a propriedade `shape: const CircleBorder()` no `FloatingActionButton` para torná-lo redondo, garantindo consistência com o `MultiActionFab` exibido nas outras abas.

### R5. Lógica de Cores Vinculada aos Medicamentos e Lembretes (C++ Alignment)
- **Grid de Cores no Assistente**: **Mantenha** o grid de seleção de cores de alarmes na tela de Opções (wizard_step_options.dart).
- **Sincronização Bidirecional e Expansão de Cores**:
  - Atualize a interface de seleção de cores (tanto na tela de cadastro/edição de medicamentos quanto no assistente de alarmes) para exibir todas as **15 cores oficiais** de hardware configuradas em `AppColors.alarmColors`, em vez de limitar a apenas 9 cores.
  - Quando um medicamento existente é selecionado no assistente (wizard_step_medication.dart), a cor dele no banco deve ser pré-selecionada automaticamente no grid do assistente.
  - Se o usuário mudar a cor no grid do assistente ou criar um medicamento novo com uma cor específica, salve o medicamento no banco com essa cor. Se for um medicamento existente, atualize a cor do medicamento correspondente no banco local (`medications`).
  - No Dashboard e em outras telas, a cor exibida para o alarme deve sempre herdar a cor do medicamento de mesmo nome (`medName`) salvo na base de dados (caso ele exista).
- **Cores dos Lembretes**:
  - Garanta que os lembretes usem estritamente cores da paleta oficial de 15 cores de medicamentos da caixinha (as chaves em `AppColors.alarmColors` do firmware C++) em vez de cores aleatórias do Flutter, para garantir compatibilidade com os LEDs do hardware.

## Acceptance Criteria

### Fechamento do Alarme Ativo
- [ ] Ao clicar em "Adiar 10 min" na tela de alarme disparado, a tela fecha com sucesso.

### Correção de Overflow e Layout
- [ ] A modal "Gerenciar Alarme" abre sem estourar e sem exibir erros de RenderFlex em um iPhone 14 Pro Max virtual.
- [ ] O FAB na tela de início é redondo (`CircleBorder`).

### Calendário sem Cintilação
- [ ] A navegação entre dias no calendário do Dashboard ocorre de forma fluida sem exibir uma tela preta/branca ou spinner centralizado de tela cheia que cause cintilação.

### Lógica de Sincronização e Expansão de Cores
- [ ] Os seletores de cores de medicamentos e alarmes (assistente e telas de CRUD de medicamentos) agora exibem e permitem selecionar todas as 15 cores oficiais de `AppColors.alarmColors`.
- [ ] A cor do medicamento no banco é pré-selecionada no grid do assistente ao escolhê-lo.
- [ ] Alterar a cor no grid do assistente e salvar o alarme propaga a atualização para o medicamento correspondente no banco local.
- [ ] Os lembretes são gerados/atribuídos usando apenas as 15 cores oficiais de hardware da caixinha (definidas no array `AppColors.alarmColors`).

## Follow-up — 2026-06-29T13:40:59Z

Refinar o layout e a usabilidade do MediCaixa App para melhorar a estética em telas largas (Desktop/macOS) e simplificar a tela inicial (Dashboard).

Working directory: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app
Integrity mode: development

## Requirements

### R1. Remoção das Setas da Calendar Strip
- No widget [calendar_strip_widget.dart](file:///Users/almanimation/Downloads/Caixa%20Remedios/medicaixa_app/lib/features/dashboard/presentation/widgets/calendar_strip_widget.dart), remover as sobreposições de setas laterais (os elementos `Positioned` que exibem os ícones `chevron_left` e `chevron_right`).
- Retornar o `ListView.builder` de forma limpa na árvore de visualização (mantendo o comportamento de arrastar para rolar nativo).

### R2. Remoção do Card "Ritmo Semanal" no Dashboard
- Na tela [dashboard_screen.dart](file:///Users/almanimation/Downloads/Caixa%20Remedios/medicaixa_app/lib/features/dashboard/presentation/dashboard_screen.dart), remover por completo o widget `WeeklyRhythmWidget` da aba Início e as chamadas de banco/histórico associadas a ele.
- O espaço horizontal liberado no Desktop deve ser ocupado inteiramente pelas seções de alarmes e lembretes.

### R3. Grid Responsivo de Alarmes e Lembretes (Dashboard)
- Na aba início [dashboard_screen.dart](file:///Users/almanimation/Downloads/Caixa%20Remedios/medicaixa_app/lib/features/dashboard/presentation/dashboard_screen.dart), quando o aplicativo rodar em telas largas (largura da tela >= 800px):
  - Distribuir os cards de alarmes (`AlarmCardWidget`) e lembretes (`ReminderCardWidget`) de cada período ativo em um grid responsivo de múltiplas colunas (utilizando `GridView.builder` com `SliverGridDelegateWithMaxCrossAxisExtent` com largura máxima de ~400px por card e `mainAxisExtent` confortável para evitar cortes de texto).
  - Em telas mobile (largura < 800px), manter o layout original em lista de coluna vertical simples.

### R4. Grid Responsivo de Medicamentos (Remédios)
- Na tela de listagem [medications_list_screen.dart](file:///Users/almanimation/Downloads/Caixa%20Remedios/medicaixa_app/lib/features/medications/presentation/medications_list_screen.dart), quando a largura da tela for >= 800px, renderizar a listagem de medicamentos cadastrados in grid de múltiplas colunas (usando `GridView.builder` com `maxCrossAxisExtent: 400` e `mainAxisExtent` adequado).
- Em telas mobile, manter o empilhamento vertical clássico de `ListView.separated`.

## Verification & Deliverables

### D1. Código Fonte
- Modificar os arquivos de UI do Dashboard, Calendar Strip e Medicamentos.
- Executar análises e builds locais para certificar de que não há nenhum overflow no layout responsivo ou quebra de componentes.

### D2. Suíte de Testes
- Rodar a suíte inteira de testes do Flutter para validar que nenhuma navegação de UI ou fluxo foi prejudicado com a remoção dos componentes.

## Acceptance Criteria

### Calendar Strip & Ritmo Semanal
- [ ] As setas `chevron_left` e `chevron_right` não são mais exibidas no topo do calendário.
- [ ] O card "Ritmo Semanal" e seu widget correspondente foram totalmente removidos do Dashboard.

### Grid Responsivo (Desktop vs. Mobile)
- [ ] Em resoluções Desktop (>= 800px), os cards de alarmes, lembretes e medicamentos aparecem distribuídos horizontalmente lado a lado em colunas fluidas (máximo de 400px de largura por card).
- [ ] Em resoluções Mobile (< 800px), os cartões continuam alinhados verticalmente ocupando toda a largura útil da coluna.
- [ ] Não ocorrem overflows de renderização (RenderFlex) ou erros visuais ao redimensionar a janela do aplicativo.
