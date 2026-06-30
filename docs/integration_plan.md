# Plano de Integração de Alarme Nativo Avançado — MediCaixa App

Este documento descreve a arquitetura de engenharia para integração de alarmes, som e notificações no MediCaixa App, garantindo 100% de autonomia offline em Android, iOS e macOS, contornando modos DND (Não Perturbe)/silencioso e garantindo a correta exibição e tocada de alarmes sobre a tela de bloqueio.

---

## 1. Arquitetura Geral

O MediCaixa App é um aplicativo offline-first. Para garantir que os alarmes agendados toquem de forma confiável sem conexão com a internet e mesmo com o aplicativo fechado ou suspenso pelo sistema operacional, utilizamos as APIs nativas de agendamento de alarmes e notificações locais de cada plataforma.

```
       ┌──────────────────────────────────────────────────────────┐
       │                 NotificationService (Dart)               │
       └─────────────────────────────┬────────────────────────────┘
                                     │
            ┌────────────────────────┼────────────────────────┐
            ▼                        ▼                        ▼
     [Android Native]          [iOS Native]            [macOS Native]
     - AlarmManager            - UNUserNotification    - UNUserNotification
     - FullScreenIntent          Center (Critical)       Center (Time-Sensitive)
     - Wake Locks              - AVAudioSession        - NSProcessInfo
     - Boot Receiver             (Audio Fallback)        (App Nap Prevention)
```

---

## 2. Integração Android

O ecossistema Android impõe restrições severas sobre background services e alarmes para otimização de bateria. O MediCaixa App utiliza as seguintes estratégias para garantir a entrega e toque dos alarmes:

### 2.1. Alarmes Exatos e Boot Resiliency
- **Permissões**: Declaramos as permissões `SCHEDULE_EXACT_ALARM` e `USE_EXACT_ALARM` para agendar alarmes com precisão de milissegundos.
- **Boot Resiliency**: Registramos o receiver `ScheduledNotificationBootReceiver` do plugin `flutter_local_notifications` para reagendar todos os alarmes ativos após a inicialização ou reinicialização do dispositivo (`RECEIVE_BOOT_COMPLETED`).
- **Wake Locks**: Declaramos `WAKE_LOCK` para permitir que o processador continue rodando enquanto o som do alarme e a tela ativa estão sendo executados.

### 2.2. Exibição Sobre a Tela de Bloqueio (Full Screen Intent)
- **FullScreenIntent**: A notificação é configurada com `fullScreenIntent` apontando para a `MainActivity` do Flutter. Isso faz com que, quando o alarme disparar com o dispositivo bloqueado, a tela de alarme ativo (`AlarmActiveScreen`) seja exibida imediatamente em tela cheia sobre a tela de bloqueio.
- **Activity Flags**: Configuramos a `MainActivity` com `android:showWhenLocked="true"` e `android:turnScreenOn="true"`, e programaticamente na criação da activity aplicamos as flags de janela para ligar a tela e contornar o bloqueio por senha de forma segura (exibindo apenas a interface de tomada do medicamento).

---

## 3. Integração iOS

O iOS possui regras restritas para execução em segundo plano e alertas audíveis quando o telefone está no modo silencioso ou Não Perturbe (DND).

### 3.1. Critical Alerts (Alertas Críticos)
- **Critical Alerts Entitlement**: Declaramos o direito `com.apple.developer.usernotifications.critical-alerts` nos entitlements do app. Isso permite que o MediCaixa envie notificações que ignoram o botão físico de silencioso do aparelho e as configurações de Foco/Não Perturbe, tocando o som de alarme no volume máximo definido.
- **Swizzling do AppDelegate**: Swizzlamos o método `add(_:withCompletionHandler:)` do `UNUserNotificationCenter` no AppDelegate Swift para interceptar notificações marcadas com `interruptionLevel == .critical` e mapeá-las para a API nativa `UNNotificationSound.criticalSoundNamed()`.

### 3.2. Fallback de Áudio e AVAudioSession
- **Background Modes**: Ativamos `audio` (reprodução de áudio em background) e `fetch` em `Info.plist`.
- **AVAudioSession**: Antes de iniciar a reprodução do som na tela ativa, configuramos o `AVAudioSession` com a categoria `.playback` e opções adequadas no Dart usando o pacote `audioplayers` para garantir que o som toque em segundo plano caso a tela seja minimizada e respeite a saída de áudio correta.

---

## 4. Integração macOS

No macOS, os alarmes do MediCaixa App usam os recursos do sistema operacional voltados a computadores Desktop, prevenindo suspensões por inatividade.

### 4.1. Time-Sensitive Alerts
- **Configuração de Notificações**: Mapeamos os alertas de medicamentos como notificações do tipo `Time-Sensitive` (`interruptionLevel: InterruptionLevel.timeSensitive`). Isso assegura que elas quebrem os modos de Foco do macOS e permaneçam visíveis no topo da tela.
- **NSUserNotificationAlertStyle**: Forçamos o estilo de exibição das notificações para `alert` em `Info.plist` para que elas exijam ação do usuário (como botões de adiar ou tomar) em vez de sumirem sozinhas (estilo `banner`).

### 4.2. Prevenção de App Nap (Assertividade de Processo)
- **App Nap**: O macOS suspende ou reduz a CPU de aplicativos que estão em segundo plano ou cobertos por outras janelas (App Nap).
- **ProcessInfo Assertions**: Criamos um Method Channel `com.medicaixa.app/app_nap` manipulado no `AppDelegate.swift` que utiliza `ProcessInfo.processInfo.beginActivity(options:reason:)` para manter o aplicativo ativo em alto desempenho e com a CPU acordada enquanto o alarme estiver disparado, encerrando a atividade (`endActivity`) imediatamente quando o alarme for concluído ou adiado.

---

## 5. Estratégia de Fallback de Som Offline

Para garantir que o alarme toque mesmo na ausência de conexão com a rede ou falhas ao carregar mídias remotas, o aplicativo adota um fluxo de reprodução de som resiliente:
1. **Recurso Nativo Local (Notificação)**: A notificação local utiliza o arquivo `alarm_beep.wav` embutido nos recursos nativos de cada plataforma (`res/raw` no Android, Main Bundle no iOS/macOS).
2. **Reprodução na Tela Ativa**: Ao carregar a tela `AlarmActiveScreen`, tentamos reproduzir o arquivo local `alarm_beep.wav` embutido no asset do Flutter (`assets/sounds/alarm_beep.wav`).
3. **Fallback Hático/Beep Resiliente**: Caso ocorra alguma falha crítica na inicialização do player de áudio ou falta de permissão, o aplicativo ativa um loop de vibração periódica (`HapticFeedback.vibrate()`) com intervalos de 2 segundos para dar o alerta tátil e auditivo (pela vibração) ao usuário.
