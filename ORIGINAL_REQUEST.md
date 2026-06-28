# Original User Request

## Initial Request — 2026-06-28T19:43:48-03:00

Corrigir a reatividade da cor da barra de navegação inferior (`AppShell`) na troca de tema, refinar a cor dos cartões de alerta ("Configurações da Caixinha Bloqueadas" e "Testes Offline") para o Tema Claro, e substituir o seletor de idiomas por um Dropdown com emojis de bandeiras semelhante ao C++ (Xiaozhi).

Working directory: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app
Integrity mode: development

## Requirements

### R1. Reatividade da Barra de Navegação Inferior (`AppShell`)
- A barra de navegação inferior (`BottomNavigationBar` ou `NavigationRail` no `app_shell.dart`) deve atualizar suas cores (background, itens selecionados e não selecionados) em tempo real assim que o tema for alterado na aba Ajustes, sem exigir a troca de aba para forçar a reconstrução visual.
- Garantir que o `AppShell` assista ao `appThemeNotifierProvider` para reconstruir-se automaticamente ao mudar o tema.

### R2. Estilo dos Cartões de Alerta no Tema Claro
- O cartão de aviso "Configurações da Caixinha Bloqueadas" e o card correspondente de "Testes Offline (Fixture)" devem ter cores harmoniosas com o Tema Claro:
  - Fundo claro em tom vermelho pastel suave (`AppColors.healthDangerBg`, correspondente a `#fef2f2`).
  - Borda discreta avermelhada (`AppColors.healthDangerBorder`, correspondente a `#fca5a5`).
  - Texto e ícone em cor vermelha/alerta legível (`AppColors.healthDanger` ou `AppColors.missed`).
- Para o cartão de "Testes Offline (Fixture)", usar o fundo padrão limpo (`AppColors.surface`) com borda do tema (`AppColors.border`) no Tema Claro para harmonizar visualmente com os demais cartões.

### R3. Seletor de Idioma via Dropdown com Bandeiras (i18n)
- Substituir o widget `SegmentedButton` de seleção de idioma por um menu dropdown (`DropdownButtonFormField`) na aba Ajustes.
- O dropdown deve listar as opções correspondentes aos idiomas suportados com o emoji da bandeira e o nome da língua correspondente (semelhante ao C++):
  - `🇧🇷 Português` (valor: `'pt'`)
  - `🇺🇸 English` (valor: `'en'`)
  - `🇪🇸 Español` (valor: `'es'`)
- Garantir que o dropdown tenha o estilo visual coerente com os demais campos da tela de ajustes (borda com `AppColors.border`, fundo com `AppColors.surface`, cor de texto `AppColors.text`) e persista a escolha corretamente na base Drift SQLite.

### R4. Testes e Estabilidade
- Atualizar ou adicionar testes de widget (incluindo `localization_test.dart` e `theme_ui_integration_test.dart`) para validar a transição dinâmica de cores do `AppShell` ao alterar o tema e o funcionamento correto da seleção do novo dropdown de idioma.
- Rodar análise estática (`flutter analyze`) e garantir zero erros e avisos.

## Acceptance Criteria

### Interface Visual (UI)
- [ ] Ao alternar o tema para "Claro" na aba Ajustes, a barra de navegação inferior muda de cor de fundo imediatamente para branco (`#ffffff` ou `AppColors.surface`).
- [ ] No Tema Claro, o card "Configurações da Caixinha Bloqueadas" possui um fundo avermelhado pastel suave e borda vermelha suave.
- [ ] O seletor de idiomas nos Ajustes Locais agora é um menu dropdown contendo as opções `🇧🇷 Português`, `🇺🇸 English` e `🇪🇸 Español`. O item selecionado no dropdown reflete o idioma ativo.

### Funcionalidade e Lógica
- [ ] A troca de idioma via dropdown altera com sucesso as traduções do app instantaneamente e persiste a alteração no Drift SQLite.
- [ ] A barra inferior e os cards de alerta reagem dinamicamente a mudanças de tema em tempo real.
- [ ] `flutter analyze` compila com 0 issues.
- [ ] A suíte de testes de widget e integração passa com sucesso.

## Follow-up — 2026-06-28T20:22:07-03:00

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
  - **Medicamentos**: inclusive tentar excluir medicamentos em uso para validar se o bloqueio de exclusão funciona conforme especificado na Regra 35.
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
