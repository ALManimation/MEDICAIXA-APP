# Referência da Web UI Existente — Para o Agente Flutter

> Este documento explica como usar a Web UI atual (HTML/CSS/JS) como referência para o desenvolvimento do app Flutter.

---

## Repositório GitHub

```
https://github.com/ALManimation/MEDICAIXA-IA.git
```

O projeto inteiro (firmware C++ + Web UI) está neste repositório. O agente Flutter pode clonar e consultar o código fonte.

---

## Arquivo Principal da Web UI

**Caminho**: `littlefs_data/www/index.html` (~13.000 linhas, 571KB)

Este é um Single Page Application (SPA) completo que roda no browser e se comunica com o ESP32 via REST API. Ele contém:

### O que extrair como referência:

| Área | O que copiar/adaptar | Onde encontrar no index.html |
|------|---------------------|------------------------------|
| **Paleta de Cores** | Map de cores `colorMap` com hex values | Buscar `colorMap` ou `getColorHex` |
| **Formulário de Alarmes** | Lógica de campos condicionais (ciclo, PRN, desmame, dose dinâmica, ajuste progressivo) | Buscar `showWizardStep` e `buildAlarmPayload` |
| **Validações** | Regras de validação de formulário (horário, doses, dias) | Buscar `validateAlarm` ou `validateWizard` |
| **Cards de Alarmes** | Layout dos cards com badges de status | Buscar `renderAlarmCard` ou `createAlarmCard` |
| **Calendar Strip** | Lógica do filtro por dia da semana | Buscar `calendarStrip` ou `filterAlarmsByDay` |
| **Dashboard** | Resumo diário (pendentes, tomados, perdidos) | Buscar `updateDashboard` ou `dailySummary` |
| **Busca de Medicamentos** | Fuzzy search com Levenshtein | Buscar `searchMedication` ou `levenshtein` |
| **i18n / Traduções** | Todas as strings traduzidas em 3 idiomas | Arquivos em `docs/reference/pt.json`, `en.json`, `es.json` |
| **Instrução Especial** | Lista de códigos e labels | Buscar `special_instruction` |
| **Dose Fracionada** | Lógica de parte inteira + metade (½) | Buscar `half` ou `dose-half` |
| **Doses Assimétricas** | Quantidade diferente por dia da semana | Buscar `days_quantity` ou `asymmetric` |
| **Suspensão/Pausa** | Modal de pausa com data de retorno | Buscar `pauseAlarm` ou `pause_until` |
| **Wizard de Criação** | Fluxo multi-step de criação de alarmes | Buscar `wizard` ou `step` |

### Padrões de UX a manter:

1. **Wizard multi-step**: Alarmes são criados em passos (medicamento → horário → tipo → dias → opções avançadas)
2. **Cards com badges visuais**: Cada card mostra badges coloridos para ciclo, PRN, dinâmico, suspenso, desmame
3. **Calendar strip horizontal**: Filtro de dias na parte superior do dashboard
4. **Atalhos rápidos**: Botões de "Antes do café", "Depois do almoço", etc. baseados nas preferências do paciente
5. **Dark mode nativo**: A UI usa fundo escuro por padrão
6. **Cores por medicamento**: Cada alarme tem uma cor associada que aparece como borda/destaque no card

---

## Arquivos de Tradução (i18n)

Copiados para `docs/reference/`:

| Arquivo | Idioma | Linhas |
|---------|--------|--------|
| `pt.json` | Português (BR) | ~700 chaves |
| `en.json` | English | ~700 chaves |
| `es.json` | Español | ~700 chaves |

Estas traduções devem ser adaptadas para o formato do Flutter (`intl` ou `easy_localization`). As chaves JSON podem ser reutilizadas diretamente.

**Exemplo de estrutura**:
```json
{
  "alarm_status_pending": "Pendente",
  "alarm_status_taken": "Tomado",
  "alarm_status_missed": "Perdido",
  "alarm_type_pill": "Comprimido",
  "alarm_type_capsule": "Cápsula",
  "alarm_type_drop": "Gota",
  "alarm_type_dose": "Dose líquida",
  "btn_save": "Salvar",
  "btn_cancel": "Cancelar",
  ...
}
```

---

## Backup JSON Real (Dados de Teste)

Para testes durante o desenvolvimento, o agente pode usar um backup real da caixinha como fixture de dados:

**Caminho no repo**: `Backups_testes/pruned_backup.json`

Este arquivo contém:
- 25 alarmes reais (incluindo alarmes com ciclo, PRN, dose dinâmica)
- 6 lembretes
- Configurações completas
- Histórico de eventos

Pode ser carregado diretamente no banco local do app para simular um cenário real sem precisar da caixinha física.

---

## Resumo: O que o Agente Flutter deve fazer

1. **Clonar o repo** ou consultar os arquivos pelo caminho relativo `../` (firmware está um nível acima)
2. **Ler o `index.html`** para entender a lógica de formulários e cards (não copiar o HTML, mas entender os fluxos)
3. **Copiar os JSONs de tradução** (`docs/reference/*.json`) e adaptar para o sistema i18n do Flutter
4. **Usar o backup** (`../Backups_testes/pruned_backup.json`) como dados de teste/fixture
5. **Manter a mesma paleta de cores** e badges visuais dos cards
6. **Reproduzir o wizard de criação** de alarmes com os mesmos passos e validações
