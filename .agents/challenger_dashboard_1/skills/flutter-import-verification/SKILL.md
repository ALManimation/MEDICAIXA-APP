---
name: flutter-import-verification
description: Verifica e corrige import paths relativos em projetos Flutter feature-first. Use quando criar ou mover arquivos Dart para calcular corretamente a profundidade de `../` nos imports relativos.
---

# Verificação de Imports Relativos Flutter

## Regra de Contagem de `../`

Para calcular o import relativo de `lib/core/xxx` a partir de qualquer arquivo:

1. Conte os diretórios entre o arquivo e `lib/`:
   - `lib/features/alarms/data/` → 3 diretórios (features, alarms, data) → `../../../core/`
   - `lib/features/alarms/presentation/wizard/steps/` → 5 diretórios → `../../../../../core/`
   - `lib/features/dashboard/presentation/widgets/` → 4 diretórios → `../../../../core/`
   - `lib/features/dashboard/presentation/` → 3 diretórios → `../../../core/`
   - `lib/core/presentation/` → 2 diretórios → `../../` para chegar a outro subdir de `core/`

2. **Fórmula**: `número de ../` = profundidade do arquivo relativo a `lib/`

3. Para imports entre features (ex: `alarms → medications`):
   - De `steps/` (5 deep) para `features/medications/` → `../../../../medications/`
   - De `data/` (3 deep) para `features/pairing/` → `../../pairing/`

## Tabela de Referência Rápida (MediCaixa)

| Diretório do arquivo | Prefixo para `core/` | Prefixo para outra `feature/` |
|---|---|---|
| `lib/features/X/data/` | `../../../core/` | `../../Y/` |
| `lib/features/X/domain/` | `../../../core/` | `../../Y/` |
| `lib/features/X/presentation/` | `../../../core/` | `../../Y/` |
| `lib/features/X/presentation/widgets/` | `../../../../core/` | `../../../Y/` |
| `lib/features/X/presentation/wizard/` | `../../../../core/` | `../../../Y/` |
| `lib/features/X/presentation/wizard/steps/` | `../../../../../core/` | `../../../../Y/` |
| `lib/core/presentation/` | `../` (para `constants/`, `theme/`, etc.) | `../../features/Y/` |

## Verificação

Antes de commitar, validar com:
```bash
# Verifica se todos os imports resolvem corretamente
flutter analyze
```

**NUNCA** usar `sed` para corrigir imports em massa — isso corrompe paths silenciosamente.
