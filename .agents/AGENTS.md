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
22. **Não usar `const` com `AppColors`**: Widgets que referenciam `AppColors.xxx` NÃO podem ser `const`. Use `Icon(Icons.alarm, color: AppColors.primary)` sem `const`. Isso inclui: `Icon`, `TextStyle`, `BorderSide`, `Divider`, `CircularProgressIndicator`, e qualquer widget que receba parâmetros de `AppColors`.
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
