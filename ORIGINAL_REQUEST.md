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
