# AGENTS.md — MediCaixa App Flutter

> Este arquivo contém as regras obrigatórias para agentes de IA que trabalham neste projeto.
> Leia por completo antes de modificar qualquer código.

---

# Instruções de Raciocínio & Pesquisa (Thinking Guardrails)

[CRITICAL INSTRUCTION FOR AI AGENTS] Diante de problemas complexos, bugs, erros ou dúvidas:

1. **Uso Explicito de Raciocínio Interno**: O Agente deve usar ativamente seu bloco de raciocínio interno para decompor o problema. Faça uma análise profunda de dependências, conflitos de programação e limitações antes de executar qualquer ação, como alteração de código, execução de scripts ou comandos.
2. **Pesquisa Ativa nas Documentações**: Em caso de erros de build, comportamentos estranhos do projeto ou dúvidas arquiteturais, utilize as ferramentas de busca locais e na web para encontrar referências na internet, em fóruns de flutter e Dart, documentação do Flutter e Dart, ou projetos open-source correlatos com arquitetura semelhante.
3. **Revisão Passo a Passo**: Antes de concluir qualquer tarefa, faça um "dry run" ou teste mental do código proposto. Não execute múltiplos passos de alteração de forma cega. Realize as tarefas uma por uma, validando o impacto de cada uma no sistema global.
4. **Metodologia de Planejamento e Execução**:
   - **Implementações Complexas**: O Agente deve obrigatoriamente apresentar um plano de implementação detalhado antes de iniciar, e criar/atualizar um arquivo `task.md` para rastrear e monitorar o progresso de cada tarefa durante a execução.
   - **Implementações Simples**: Mesmo em alterações pequenas ou rápidas, o Agente deve sempre explicar de forma clara o que pretende fazer antes de modificar qualquer código.

---

## Stack Tecnológica

- **Framework**: Flutter 3.x + Dart 3.x
- **State Management**: Riverpod 2.x (com code generation via `riverpod_annotation`)
- **Banco de Dados Local**: Drift (SQLite) com streams reativos
- **HTTP Client**: Dio 5.x com interceptors
- **Arquitetura**: Feature-First Clean Architecture (data / domain / presentation)
- **Plataformas**: iOS, Android, macOS Desktop

## Regra de Ouro

> **Em caso de dúvida, SEMPRE busque respostas no projeto C++ da MediCaixa.** O projeto C++ (firmware + Web UI) está em desenvolvimento há mais de um mês e suas lógicas estão 99% revisadas. O app Flutter é uma **cópia fiel** das funcionalidades, lógicas e interface já existentes. Consulte:
> - **Web UI**: `../Versoes/08.90 C++ Xiaozhi/littlefs_data/www/index.html` (13.143 linhas) — Interface, fluxos, validações
> - **Firmware C++**: `../Versoes/08.90 C++ Xiaozhi/components/` — Lógica de negócio (AlarmManager, ReminderManager, WebServer)
> - **WebServer handlers**: `../Versoes/08.90 C++ Xiaozhi/components/web_server/` — Endpoints REST, payloads, respostas
>
> Todas as respostas sobre como algo deve funcionar estão lá.

---

## Regras Obrigatórias

### Arquitetura e Padrões

1. **Offline-First**: A UI SEMPRE lê do banco local (Drift/SQLite). Nunca faça chamadas HTTP diretas na camada de apresentação.
2. **Repository Pattern**: Toda comunicação com o dispositivo MediCaixa passa pelo Repository, que decide se lê do cache local ou da rede.
3. **AsyncValue**: Use `AsyncValue` do Riverpod para todos os estados assíncronos. Nunca use flags manuais `isLoading` ou `hasError`.
4. **Isolates para CPU-heavy**: Busca de medicamentos ANVISA e parsing de JSON grande devem rodar em `Isolate` dedicado para não bloquear a UI.
5. **Tratamento de Erros**: Todo `try/catch` deve retornar mensagens estruturadas ao usuário, nunca falhar silenciosamente.
6. **Feature-First**: Cada feature tem suas próprias pastas `data/`, `domain/`, `presentation/`. Não misturar código entre features.

### Comunicação com MediCaixa (ESP32)

7. **Nomes de Campos JSON**: Usar `snake_case` nos JSONs (ex: `med_name`, `last_status_date`, `days_quantity`) para compatibilidade com o firmware C++.
8. **Timeouts**: Toda requisição HTTP deve ter timeout de **5 segundos** (o ESP32 é local na LAN, respostas são rápidas).
9. **Serializar Requisições**: Não fazer muitas requisições HTTP simultâneas ao ESP32. A DRAM é limitada (~270KB). Serializar chamadas.
10. **Parsing de `quantity`**: O campo `quantity` vem como `int` quando inteiro e `float` quando fracionado. Sempre parsear como `double`: `(json['quantity'] as num).toDouble()`.
11. **Campos Opcionais Avançados**: Campos como `cycle_on_days`, `is_prn`, `taper_stages` **não existem** no JSON se inativos. Usar `json.containsKey()` ou defaults no `fromJson`.
12. **IDs**: O `id` do alarme é `uint8_t` no firmware (0-255). IDs temporários locais (criados offline) devem ser > 255 para evitar conflitos.

### App Autônomo

13. **Funcionalidade Standalone**: O app DEVE funcionar 100% sem a caixinha MediCaixa conectada. Todas as features (criar alarme, buscar medicamento, ver histórico) devem operar com dados locais.
14. **Sincronização Opcional**: A sincronização com o dispositivo é um recurso adicional, não um requisito. Se a caixinha não for encontrada na rede, o app continua funcionando normalmente.

### Design e UX

15. **Material 3**: Usar Material Design 3 com tema escuro como padrão (pacientes usam à noite).
16. **Google Fonts**: Usar `Inter` ou `Roboto` para body text, `Outfit` para headings.
17. **Layout Responsivo**: Em telas grandes (macOS), usar layout de 2 colunas (sidebar + content). Em mobile, usar navegação por tabs/bottom nav.
18. **Micro-animações**: Adicionar transições suaves entre telas e feedback visual em interações.

### Qualidade

19. **Testes**: Escrever testes unitários para Repositories e ViewModels/Notifiers.
20. **Documentação**: Documentar classes públicas com dartdoc comments.

### Armadilhas Conhecidas (Aprendidas em Sessões Anteriores)

21. **Nunca usar `sed`/`awk`/regex em arquivos Dart**: Substituições em massa com `sed` corrompem imports e strings silenciosamente. Sempre usar as ferramentas de edição do IDE (`replace_file_content` / `multi_replace_file_content`) que são type-safe e mostram diffs verificáveis.
22. **Não usar `const` com `AppColors`**: Como a classe `AppColors` utiliza variáveis estáticas dinâmicas não-finais para alternar cores entre os temas Claro e Escuro, widgets que referenciam `AppColors.xxx` NÃO podem ser declarados como `const`. Use `Icon(Icons.alarm, color: AppColors.primary)` sem `const`. Isso se aplica a `Icon`, `TextStyle`, `BorderSide`, `Divider`, `CircularProgressIndicator` e qualquer outro widget parametrizado por `AppColors`.
23. **Nomes de Classes Drift**: O Drift gera classes de dados com o nome **singular** da tabela (ex: tabela `settings` → classe `Setting`, tabela `alarms` → classe `Alarm`). Nunca adicionar sufixo `Data` (ex: `SettingsData` está ERRADO). Consulte o arquivo `.g.dart` gerado em caso de dúvida.
24. **Import de `Ref`**: O tipo `Ref` do Riverpod requer `import 'package:flutter_riverpod/flutter_riverpod.dart'`. O pacote `riverpod_annotation` **não** exporta `Ref`. Sempre adicionar ambos os imports quando usar `@riverpod` com `Ref`.
25. **Flutter 3.44+ Breaking Changes**: No Flutter 3.44+, `CardTheme` foi renomeado para `CardThemeData` no contexto de `ThemeData.copyWith(cardTheme: ...)`. Usar `CardThemeData(...)` em vez de `CardTheme(...)`.
26. **Análise de UI em `index.html`**: Nunca dependa exclusivamente de referências visuais (screenshots) ao replicar componentes UI do C++ para o Flutter. Sempre procure no arquivo `index.html` o elemento correspondente (via ID ou Classe CSS) e analise detalhadamente a sua **Árvore DOM (Hierarquia)** (para entender contêineres e posicionamento) e as suas **Funções JavaScript** (para compreender interações dinâmicas de estilo e texto).
27. **Busca e Autocomplete (Fuzzy & Ordenação)**: Ao realizar buscas locais, é OBRIGATÓRIO normalizar as strings (remover acentos) antes das comparações. Agrupe resultados em ordem de relevância (Nome > Nome Aproximado > Genérico). A ordenação final dentro de cada grupo DEVE priorizar o tamanho da string (`length`) antes da ordem alfabética, garantindo que nomes curtos e exatos apareçam primeiro.
28. **Riverpod e LateInitializationError**: Nunca armazene Providers em variáveis `late final` dentro de Notifiers. O Flutter chama `build()` novamente em Hot Reloads, causando crashes. Use getters dinâmicos (ex: `AlarmRepository get _repo => ref.read(alarmRepositoryProvider);`).
29. **Prevenção de Duplicação Visual**: Antes de adicionar novos campos (ex: "Dosagem"), o Agente DEVE ler detalhadamente a classe completa correspondente e o `index.html` de referência para não injetar componentes que já existem mais abaixo no código.
30. **Prevenção de Overflow e Alinhamento em Cards**: Ao implementar grids ou rows de cartões com ícones/emojis e texto, evite fixar a propriedade `height`. Prefira usar `BoxConstraints(minHeight: ...)` associado a `IntrinsicHeight` com `CrossAxisAlignment.stretch` nas fileiras (`Row`) para manter todos os cartões com a mesma altura automaticamente sem quebras de layout.
31. **Salvamento de Múltiplos Alarmes**: Conforme as lógicas originais do firmware C++, se o usuário configurar o horário como customizado (`custom`) e adicionar múltiplos tempos (ex: 08:00 e 20:00), o sistema deve salvar **alarmes individuais separados** na base local (um para cada horário).
32. **Verificação de Contexto Assíncrono (mounted)**: Em operações assíncronas dentro de Widgets e telas, use `context.mounted` em vez de apenas `mounted` para silenciar os lints modernos do Flutter SDK (> 3.20) e garantir a segurança do ciclo de vida do widget.
33. **Ocultação de Lembretes Vazios**: Se a lista de lembretes para a data selecionada no Dashboard estiver vazia, oculte toda a seção de lembretes retornando `const SizedBox.shrink()`. Não exiba cabeçalhos vazios ou placeholders que ocupem espaço visual desnecessariamente.
34. **Visual Pill-Cards de Medicamentos**: A listagem de medicamentos cadastrados deve renderizar cartões em estilo "pílula", com cantos super arredondados (`BorderRadius.circular(30)`) e bordas externas grossas (`width: 2.5`) correspondentes às cores selecionadas do medicamento, sem traçar botões redundantes.
35. **Impedir Exclusão de Medicamentos em Uso**: Antes de excluir qualquer medicamento da base de dados, consulte o `AlarmRepository`. Se o medicamento estiver em uso em algum alarme cadastrado, bloqueie a exclusão e alerte o usuário listando os alarmes impeditivos.
36. **Estrutura Global de 4 Abas**: A navegação principal (`AppShell`) deve expor obrigatoriamente 4 abas: Início (Dashboard), Remédios (Medications), Relatórios (History & Logs) e Ajustes (Settings), replicando a coerência visual da Web UI do Xiaozhi.
37. **Parâmetros Nulos em copyWith do Drift**: Nas classes geradas de dados do Drift (como `Medication`), os campos opcionais e nulos no `copyWith` esperam `Value<T?>` (ex: `lastModified: Value(timestamp)`), enquanto campos obrigatórios e não-nulos esperam o tipo primitivo plano (ex: `pendingSync: false`).
38. **Inicialização e Zone Mismatch (main.dart)**: Ao utilizar o MCP Toolkit ou pacotes que gerenciam a inicialização do Flutter envelopando o `runApp`, certifique-se de chamar `WidgetsFlutterBinding.ensureInitialized()` dentro da mesma zona onde `runApp` é executado (dentro do callback `runApp: () { ... }` do bootstrap) para evitar crashes do framework. Além disso, qualquer inicialização que dependa dos bindings (como carregar traduções via `rootBundle` ou carregar locales de data) deve ser postergada para dentro deste mesmo callback, executando obrigatoriamente após o `ensureInitialized()`.
39. **Formatos de Data no Status de Alarmes (`lastStatusDate`)**: O formato persistido e comparado para logs e status de alarmes é estritamente `DD/MM/YYYY` (formato brasileiro/firmware). Nunca salve datas de status no formato ISO (`YYYY-MM-DD`), caso contrário o motor de alarmes local não reconhecerá a data de hoje e causará re-disparos infinitos por interpretar erroneamente que mudou o dia (Daily Tick).
40. **Prevenção de Loops no Motor de Alarmes**: Para evitar que um alarme já tomado ou ignorado volte a tocar dentro de sua janela de ativação de 10 minutos, o loop do motor local de alarmes deve checar se o alarme foi processado hoje (`lastStatusDate == hoje` e status diferente de `PENDENTE`) logo no início do tick e dar `continue` (exceto para medicamentos sob demanda `is_prn`).
41. **Otimização de Notificações Locais (Redundant Rescheduling)**: O agendamento de notificações no sistema operacional deve ser condicionado a um hash das propriedades estrutural do alarme (horário, dias, etc). Evite cancelar e remarcar todos os alarmes do sistema nativo para simples mudanças de estado do app (como marcações de tomada de dose).
42. **API do flutter_timezone (v5.x)**: O método `FlutterTimezone.getLocalTimezone()` retorna um objeto `TimezoneInfo` em vez de uma `String`. Use `.identifier` sobre o retorno para obter o nome IANA correto (ex: `America/Sao_Paulo`).
43. **DarwinInitializationSettings (flutter_local_notifications)**: Ao inicializar o plugin de notificações locais para plataformas Apple, evite utilizar o parâmetro `onDidReceiveLocalNotification`, pois ele foi descontinuado ou não é suportado para Darwin/macOS, causando falhas de compilação.
44. **Prevenção de RangeError em List.generate**: Em componentes de layout com listas dinâmicas calculadas por fórmulas (ex: `stages.length * 2 - 1`), certifique-se de validar se a lista de origem está vazia antes de executar a geração. Adicione sempre uma cláusula de escape `if (stages.isEmpty) return const SizedBox.shrink();` para impedir exceções de tamanho negativo que causem falhas de compilação ou desconexão do dispositivo de depuração.
45. **Persistência de Frequência de Dias Alternados (`interval_days`)**: Ao salvar frequências "A cada N dias" configuradas no assistente de criação de alarmes, grave o valor na coluna `intervalDays` (mapeada no JSON como `interval_days`). O campo `adjustIntervalDays` é de uso exclusivo para lógicas de desmame e variação gradual de dose e não deve ser usado para espaçamento comum de dias.
46. **Sobrescrita de Quantidade Customizada no markTaken**: A lógica do repositório e a chamada da API do dispensador (`markTaken`) devem suportar um parâmetro de quantidade opcional (`customQty` / `qty`). Se informado, este valor substitui a quantidade calculada para o dia atual no histórico de tomadas e no payload enviado ao hardware do ESP32 (especialmente crítico para doses dinâmicas).
47. **Reconstrução e Estilo de Alarmes Fantasmas ("Ghost Alarms")**: Em telas de calendário de dias passados, se o histórico de eventos contiver a tomada de um alarme que já foi deletado do banco de dados principal de alarmes, o sistema deve recriá-lo em memória com a propriedade `isGhost: true`. Esses cartões devem ser estilizados com bordas e ícones na cor cinza, menor opacidade (0.55), badge "Excluído" e ter cliques desabilitados.
48. **Matching e Auto-Preenchimento em Escalas Dinâmicas**: Diálogos de medicamentos dinâmicos (como insulina por escala móvel) devem exibir as regras formatadas em linguagem amigável ao usuário. Ao receber o valor medido correspondente (ex: nível de glicose), o formulário deve realizar o matching automático contra a instrução descrita para calcular e sugerir a dose sugerida ideal no campo de preenchimento.
49. **Diferenciação de Alarmes Datados vs Recorrentes**: Um alarme só deve ser classificado como "datado" (tratamento com término específico) se possuir data de início (`startDate`) válida E duração maior que zero (`durationDays > 0`). Caso contrário (quando `durationDays == 0`), mesmo que contenha uma data de início, ele é considerado um alarme recorrente permanente. A falta desta validação distorce a lógica de limites futuros e dots no calendário.
50. **Cálculo de Pontos (Dots) no Calendário**: Os dots coloridos indicativos de eventos (recorrente, específico, lembrete) desenhados na `CalendarStripWidget` devem sempre ser calculados usando as listas completas e não-filtradas de alarmes (`allAlarms`) e lembretes (`allReminders`). Usar as listas filtradas do dia selecionado no estado causará a réplica indesejada dos mesmos pontos em todos os dias do calendário conforme o usuário navega pelas datas.
51. **Fluxo de Inicialização do Aplicativo**: O aplicativo deve inicializar diretamente no painel principal (`AppShell`), abrindo na aba "Início" (Dashboard). Não force o usuário a passar pela tela de pareamento (`PairingScreen`) na inicialização. A tela de pareamento deve ser aberta exclusivamente sob demanda (ex: ao tocar em botões de parear ou nos avisos de caixinha bloqueada).
52. **Layout de Ajustes (Locais vs. Caixinha)**: A tela de ajustes (`SettingsScreen`) deve separar nitidamente as configurações locais do aplicativo (idioma, cronogramas de sono/refeições locais, etc.) dos ajustes físicos do dispositivo. Quando desconectado (modo Standalone), desabilite visualmente a seção do dispositivo (com `IgnorePointer` e opacidade de `0.55`) e exiba um único card explicativo *"Configurações da Caixinha Bloqueadas"* com o botão para conectar. O card de status de conexão ativo (com IP e versão de firmware) deve aparecer apenas quando o dispositivo estiver conectado.
53. **Prevenção de Atalhos Redundantes na Aba Ajustes**: Não adicione cartões de navegação ou atalhos na aba Ajustes para seções que já possuem acesso principal na barra inferior de abas (como "Medicamentos Cadastrados" ou redirecionamento direto para telas de histórico que tenham abas dedicadas), reduzindo a duplicação de acessos na tela de configurações.
54. **Contagem de Alarmes Perdidos em Seções Retráteis**: Na visualização do Dashboard, as seções de período (Manhã, Tarde, Noite) devem exibir a contagem de alarmes programados e, caso haja doses perdidas no dia atual, destacar a quantidade de perdas na cor vermelha (ex: `• 1` em vermelho) ao lado do total para oferecer feedback visual instantâneo.
55. **Lógica de Colapso por Conclusão de Doses**: Para focar a atenção do usuário nas ações restantes do dia, as seções do Dashboard devem iniciar colapsadas automaticamente se todos os alarmes daquela seção já tiverem sido concluídos, pulados, suspensos ou perdidos (ou seja, quando não restarem mais doses pendentes a serem tomadas no período atual).
56. **Inicialização de Testes de Layout e Internacionais (Localization & Viewport)**: Ao escrever testes de widget no Flutter para telas que exibem datas localizadas (como Dashboard com calendário) ou elementos densos, certifique-se de: (a) Inicializar a formatação local no setup (`await initializeDateFormatting('pt_BR', null)` do pacote `intl`) para evitar falhas de locale não inicializado; (b) Configurar o tamanho do viewport de teste (ex: `Size(400, 800)`) para evitar overflows artificiais e falsos negativos nos testes.
57. **Normalização de Locales e Códigos de Idioma**: Sempre normalize os códigos de idioma (ex: convertendo `pt_BR`, `pt_PT` ou `en_US` para a raiz de 2 letras `pt`, `en`, `es`) antes de salvar no banco de dados, alterar o estado de locale ou comparar contra os valores de componentes de seleção (como `SegmentedButton` ou Dropdowns). Isso previne falhas de carregamento de assets locais e garante a seleção correta dos botões na interface.
58. **Evitar Cores Hardcoded para Textos e Ícones (Temas Claro/Escuro)**: Nunca utilize cores absolutas fixas como `Colors.white`, `Colors.white70`, `Colors.white38` ou `Colors.black` para rotular textos, títulos, descrições ou ícones em cards e botões. Em vez disso, utilize referências semânticas e dinâmicas (como `AppColors.text`, `AppColors.textMuted` ou `Theme.of(context).colorScheme.onSurface`) para assegurar contraste adequado e legibilidade tanto em Light Mode quanto em Dark Mode.
59. **Drift NativeDatabase no iOS e macOS**: Sempre inicialize a conexão com o banco de dados usando `NativeDatabase(file)` de forma síncrona na thread principal se a plataforma for iOS ou macOS. Evite usar `NativeDatabase.createInBackground(file)` nesses sistemas operacionais para prevenir o erro `SqliteException(14): unable to open database file` decorrente de travas de concorrência e restrições de isolates da sandbox da Apple.
60. **Prevenção de Bugs Temporais (Flaky Tests)**: Ao simular eventos de histórico ou alarmes para "hoje" em testes unitários/widgets, certifique-se de configurar o horário dos timestamps para o início do dia (ex: `todayMidnight + 1 minuto` ou `60 * 1000` milissegundos). Evite horários mais tardios do dia (como 10h ou 12h) para impedir que o teste falhe intermitentemente dependendo da hora local em que for executado no computador.
61. **Evitar inMinutes para Gatilhos de Alarmes**: A propriedade `Duration.inMinutes` do Dart realiza truncamento inteiro em direção a zero. Diferenças negativas menores que 1 minuto (ex: -30s) resultam em 0 minutos, ativando gatilhos de `diff >= 0` precocemente. Use `(diff.inSeconds / 60.0).floor()` ou `isBefore()` para maior precisão de timing.
62. **Entitlements de Alertas Críticos no macOS**: Não declare a entitlement `com.apple.developer.usernotifications.critical-alerts` no macOS durante o desenvolvimento local. Isso bloqueia compilações devido a restrições de assinatura do Xcode. Use notificações do tipo `Time-Sensitive` no macOS e reserve Alertas Críticos estritamente para o iOS.
63. **Resiliência e Paridade de Arquivos de Som**: Qualquer som de alarme personalizado oferecido na interface deve estar presente tanto em `assets/sounds/` quanto nas respectivas pastas de recursos nativos das plataformas (`res/raw` no Android e main bundles no iOS/macOS) para garantir paridade total entre alarmes de foreground e notificações nativas de background.

---

## Comandos

```bash
# Desenvolvimento
flutter run                    # Mobile (iOS/Android)
flutter run -d macos           # macOS Desktop

# Build
flutter build apk              # Android APK
flutter build ios              # iOS (requer Xcode)
flutter build macos            # macOS app

# Testes
flutter test                   # Rodar todos os testes

# Code Generation (Drift + Riverpod)
dart run build_runner build --delete-conflicting-outputs

# Análise
flutter analyze                # Lint e análise estática
```

---

## Configuração de Plataforma

### iOS — `ios/Runner/Info.plist`
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>MediCaixa precisa acessar a rede local para conectar ao dispensador.</string>
<key>NSBonjourServices</key>
<array>
  <string>_http._tcp</string>
</array>
```

### Android — `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
```

### macOS — `macos/Runner/*.entitlements`
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

---

## Arquivos Proibidos de Editar

- `assets/medications_db.json.gz` — Gerado externamente, não modificar manualmente
- Arquivos em `build/` e `.dart_tool/`
- Arquivos gerados por `build_runner` (`.g.dart`, `.freezed.dart`)

---

## Referências

### Documentação Local
- **Guia Técnico Completo**: `docs/guia_tecnico.md` — Arquitetura, API REST, modelos de dados, motor de sincronização
- **Referência de API**: `docs/api_reference.md` — Lista resumida de todos os endpoints HTTP do ESP32
- **Referência da Web UI**: `docs/referencia_web_ui.md` — Como usar a interface web existente como base de design

### Repositório GitHub (Firmware + Web UI)
```
https://github.com/ALManimation/MEDICAIXA-IA.git
```
O código do firmware C++ e da Web UI funcional está neste repositório. Arquivos relevantes:
- **Web UI completa**: `../littlefs_data/www/index.html` (~13.000 linhas) — SPA funcional com todos os fluxos de criação/edição de alarmes, dashboard, busca de medicamentos, wizard multi-step. **Use como referência de UX e lógica de negócio.**
- **Traduções (i18n)**: `docs/reference/pt.json`, `en.json`, `es.json` — ~700 chaves traduzidas para 3 idiomas
- **Dados de Teste**: `test/fixtures/sample_backup.json` — Backup real com 25 alarmes e 6 lembretes para usar como fixture
- **Firmware Source**: `../components/` — Código C++ dos componentes (AlarmManager, ReminderManager, WebServer)

### Caminhos Locais (Ambiente de Desenvolvimento)
- **Web UI de Referência (13.143 linhas, versão completa)**: `../Versoes/08.90 C++ Xiaozhi/littlefs_data/www/index.html`
- **Web UI simplificada (1.992 linhas, versão anterior)**: `../Versoes/08.90 C++ Xiaozhi AntesGitHub/littlefs_data/www/index.html`
- **Flutter SDK**: `/opt/homebrew/share/flutter` (v3.44.4)

### Lógica de UI (Dashboard & Agrupamentos)
- **Madrugada**: O período das 00:00 às 04:59 pertence logicamente ao grupo **"Manhã"** (00:00 - 11:59). Não agrupar em "Noite".
- **Sob Demanda (PRN)**: Medicamentos com `is_prn = true` **não** entram nos grupos de horário. Devem ser exibidos em uma seção exclusiva "Sob Demanda (PRN)".

### Teste Visual e Tooling
- **UI Testing via MCP**: O app utiliza o `mcp_toolkit` para análise visual via IDE. Em vez de pedir screenshots, utilize as ferramentas `mcp_toolkit` (Semantic Snapshots, Widget Inspector e Dart Tooling Daemon) para navegar no app, "ver" os botões e validar layouts de forma autônoma.
