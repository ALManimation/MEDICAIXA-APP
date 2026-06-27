# MediCaixa App — Aplicativo Multiplataforma Flutter

Aplicativo oficial da **MediCaixa** — dispensador inteligente de medicamentos.

## Plataformas
- 📱 iOS
- 🤖 Android  
- 🖥️ macOS Desktop

## O que é este app?

Um app **autônomo** para gerenciar alarmes de medicamentos, lembretes médicos e histórico de tomadas. Funciona 100% offline e **opcionalmente** sincroniza com o dispositivo físico MediCaixa (ESP32-S3) via rede Wi-Fi local.

## Documentação

| Arquivo | Descrição |
|---------|-----------|
| `.agents/AGENTS.md` | Regras obrigatórias para agentes de IA |
| `docs/guia_tecnico.md` | Guia técnico completo (arquitetura, API, modelos, sync) |
| `docs/api_reference.md` | Referência rápida dos endpoints REST da MediCaixa |
| `assets/` | Assets compartilhados (banco ANVISA, etc.) |

## Setup Rápido

```bash
# 1. Criar projeto Flutter (dentro desta pasta)
flutter create --org com.medicaixa --project-name medicaixa_app .

# 2. Habilitar macOS
flutter config --enable-macos-desktop

# 3. Instalar dependências (após configurar pubspec.yaml)
flutter pub get

# 4. Gerar código (Drift + Riverpod)
dart run build_runner build --delete-conflicting-outputs

# 5. Rodar
flutter run              # Mobile
flutter run -d macos     # Desktop
```

## Estrutura Alvo

```
lib/
├── core/
│   ├── constants/         ← Cores, strings, configs globais
│   ├── network/           ← Cliente HTTP (Dio), discovery mDNS
│   ├── database/          ← Drift (SQLite) para persistência local
│   ├── security/          ← Armazenamento seguro de tokens
│   ├── theme/             ← Tema Material 3, tipografia, paleta
│   └── utils/             ← Helpers de formatação e validação
├── features/
│   ├── pairing/           ← Descoberta mDNS + emparelhamento
│   ├── alarms/            ← CRUD de alarmes de medicamentos
│   ├── reminders/         ← Lembretes (consultas, exames)
│   ├── medications/       ← Busca ANVISA com fuzzy matching
│   ├── history/           ← Histórico de eventos
│   ├── settings/          ← Configurações do app + dispositivo
│   └── dashboard/         ← Tela inicial com resumo do dia
├── app.dart               ← MaterialApp, rotas, providers
└── main.dart              ← Entry point
```
