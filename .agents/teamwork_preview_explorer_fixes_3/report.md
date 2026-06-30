# Relatório de Investigação Exploratória - Fixes 3

Este relatório detalha as descobertas e propostas técnicas para três melhorias principais na experiência e robustez do aplicativo **MediCaixa**:
1. **Layouts de Grid Responsivos (>= 800px)** no Dashboard e na listagem de Medicamentos.
2. **Notificações Nativas Avançadas e Configuração do Sistema Operacional** para Android, iOS e macOS.
3. **Controles Customizados de Seleção (Standard Stepper e Vertical DateTime Selectors)** com suporte a toque rápido e aceleração em clique longo.

---

## 1. Layouts de Grid Responsivos (>= 800px)

### Descobertas
Ao investigar a estrutura de layout do Dashboard e da listagem de Medicamentos, foi verificado que ambos já implementam detecções dinâmicas de largura (`MediaQuery.of(context).size.width >= 800`) para renderizar layouts adaptativos em visualizações de tela ampla (como no macOS ou tablets em modo paisagem).

#### A. Dashboard (`lib/features/dashboard/presentation/dashboard_screen.dart`)
- **Alarmes**: Renderizados usando `GridView.builder` com um `SliverGridDelegateWithMaxCrossAxisExtent` e limite de 400px.
  - *Detalhe do Código Atual:*
    ```dart
    if (isWide) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 140,
        ),
        itemCount: alarms.length,
        itemBuilder: (context, idx) => buildCard(alarms[idx]),
      );
    }
    ```
- **Lembretes**: Também renderizados adaptativamente de forma similar.
  - *Detalhe do Código Atual:*
    ```dart
    if (isWide) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 100,
        ),
        itemCount: state.reminders.length,
        itemBuilder: (context, idx) => buildReminderCard(state.reminders[idx]),
      );
    }
    ```

#### B. Lista de Medicamentos (`lib/features/medications/presentation/medications_list_screen.dart`)
- A lista de medicamentos renderiza cartões em formato "pílula" de forma responsiva.
  - *Detalhe do Código Atual:*
    ```dart
    if (isWide) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 90,
        ),
        itemCount: filteredList.length,
        itemBuilder: buildItem,
      );
    }
    ```

### Análise e Recomendações
1. **Comportamento do `SingleChildScrollView`**: 
   - No **Dashboard**, os Grids estão aninhados dentro do scroll de toda a página (`SingleChildScrollView`). Por isso, a utilização de `shrinkWrap: true` e `physics: const NeverScrollableScrollPhysics()` é essencial para evitar bugs de rolagem dupla e problemas severos de performance por renderização não-lazy.
   - Na **Lista de Medicamentos**, o `GridView.builder` está dentro de um widget `Expanded` ocupando a área disponível e rolando por si só. Portanto, **não** necessita de `shrinkWrap: true` ou `NeverScrollableScrollPhysics()`, o que é ideal para a performance pois o Flutter consegue instanciar elementos sob demanda (lazy-loading).
2. **Responsividade Fluida**: O uso de `SliverGridDelegateWithMaxCrossAxisExtent` garante que, se o contêiner crescer além de 800px (por exemplo, 1200px), a UI dividirá o espaço em 3 colunas de no máximo 400px cada automaticamente, mantendo a consistência visual com a Web UI sem a necessidade de múltiplos breakpoints arbitrários.

---

## 2. Notificações Nativas Avançadas e Configurações de OS

### Descobertas
A investigação detalhada do `NotificationService` (`lib/core/services/notification_service.dart`) e das configurações das plataformas revelou a seguinte infraestrutura:

#### A. Android (`android/app/src/main/AndroidManifest.xml`)
- Declara as permissões necessárias para alarmes críticos e bypass de tela de bloqueio:
  - `<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>` (Uso de Intents de tela cheia para mostrar alertas imediatos ao tocar alarmes).
  - `<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>` e `<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>` (Para disparo preciso em segundo plano).
  - `<uses-permission android:name="android.permission.WAKE_LOCK"/>` e `<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>` (Para acordar o dispositivo e reagendar alarmes pós-boot).
- A `MainActivity` declara propriedades críticas:
  - `android:showWhenLocked="true"`
  - `android:turnScreenOn="true"`
- No código Dart (`NotificationService.dart`):
  - Configura `fullScreenIntent: true` e `category: AndroidNotificationCategory.alarm` nas instâncias de `AndroidNotificationDetails`.
  - Associa o uso de áudio do alarme com `audioAttributesUsage: AudioAttributesUsage.alarm`.

#### B. iOS/macOS (`ios/Runner/Runner.entitlements` & `NotificationService.dart`)
- **iOS Entitlements**: O arquivo `Runner.entitlements` contém a declaração de alertas críticos para iOS:
  ```xml
  <key>com.apple.developer.usernotifications.critical-alerts</key>
  <true/>
  ```
- **macOS Entitlements**: Corretamente **não** declara o direito de alertas críticos em `DebugProfile.entitlements` e `Release.entitlements` para evitar erros de assinatura de provisionamento local durante o desenvolvimento (respeitando a regra de negócio do projeto).
- **Interruption Levels**:
  - Para iOS, configura: `interruptionLevel: InterruptionLevel.critical` (Faz o alerta bypassar DND e interruptores físicos de silêncio se o usuário conceder a permissão).
  - Para macOS, configura: `interruptionLevel: InterruptionLevel.timeSensitive` (Garante que seja exibido imediatamente sem bloquear o build local).
- **AVAudioSession**: O método `configureAudioSessionForPlayback` define a categoria global de reprodução de áudio:
  ```dart
  iOS: AudioContextIOS(
    category: AVAudioSessionCategory.playAndRecord,
    options: {
      AVAudioSessionOptions.defaultToSpeaker,
      AVAudioSessionOptions.mixWithOthers,
      AVAudioSessionOptions.allowBluetooth,
      AVAudioSessionOptions.allowBluetoothA2DP,
    },
  )
  ```

### Proposta de Atualizações para Notificações
Para garantir a máxima confiabilidade dos alarmes nativos de medicamentos (especialmente em segundo plano e dispositivos bloqueados), as seguintes melhorias técnicas devem ser adotadas:

1. **Ignorar Otimização de Bateria no Android**:
   - Para evitar que o sistema Android suspenda as tarefas de segundo plano que processam os alarmes, é recomendável adicionar a permissão de bypass de bateria no `AndroidManifest.xml`:
     ```xml
     <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
     ```
   - No app, integrar uma verificação nativa (utilizando pacotes como `permission_handler`) para solicitar ao usuário que desative as otimizações de energia para o MediCaixa.
2. **Gerenciamento Dinâmico de Permissões Android 14+ (API 34)**:
   - A partir do Android 14, o uso de `USE_FULL_SCREEN_INTENT` pode ser bloqueado por padrão para apps recém-instalados. Recomendamos implementar um fluxo nativo para checar a permissão e direcionar o usuário para a tela correspondente se negada:
     ```dart
     // Pseudocódigo de verificação nativa
     if (sdkVersion >= 34) {
       final hasFsIntent = await checkFullScreenIntentPermission();
       if (!hasFsIntent) {
         await openFullScreenIntentSettings();
       }
     }
     ```
3. **Paridade de Áudio e AVAudioSession no iOS**:
   - O uso de `AVAudioSessionCategory.playAndRecord` é apropriado para apps que gerenciam áudio de forma bidirecional. No entanto, para alarmes puros de reprodução de som e máximo volume de speaker, a categoria `AVAudioSessionCategory.playback` oferece melhor isolamento contra interrupções de chamadas de voz externas. Se o app não gravar voz, migrar para `AVAudioSessionCategory.playback`.
   - Adicionar o parâmetro de volume físico absoluto se for necessário forçar o som ao máximo ao disparar uma notificação crítica em segundo plano.

---

## 3. Seletores e Steppers Customizados

### Estado Atual na Base de Código
Atualmente, o aplicativo possui uma fragmentação visual e de interações em seus componentes de incremento e escolha de data/hora:
1. **Wizard de Quantidade (`step_3_qty.dart`)**:
   - `_buildLargeStepper` e `_buildMiniStepper` criados com botões circulares normais usando `GestureDetector(onTap: ...)`. Eles reagem apenas ao clique simples (tap). Não há suporte para pressionar continuamente para acelerar incrementos.
2. **Wizard de Duração (`step_6_duration.dart`)**:
   - `_buildDurationDaysStepper` usa botões normais de `IconButton` (`Icons.remove` / `Icons.add`) com verificação apenas via clique unitário.
3. **Seletor de Horários (`step_5_time.dart` e `wizard_step_schedule.dart`)**:
   - Abre o seletor padrão do Material Design (`showTimePicker`), que apresenta um relógio visual de ponteiros ou campo de texto flutuante nativo. No tema escuro do aplicativo, isso pode quebrar o fluxo imersivo da UI.
4. **Formulários Gerais (Medicamentos/Configurações)**:
   - Utilizam `showDatePicker` e `showTimePicker` padrão do sistema operacional, exibindo diálogos pesados em formato modal.

### Proposta de Implementação dos Controles Customizados

Propomos a criação de dois novos componentes reutilizáveis padrão dentro do diretório de widgets globais do core (`lib/core/presentation/widgets/`).

#### A. StandardStepper (160px - 180px)
Este componente unifica os steppers fragmentados. Implementa suporte a toque instantâneo e **aceleração inteligente ao manter o botão pressionado**.

##### Código de Referência para Implementação:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class StandardStepper extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String label;

  const StandardStepper({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 100.0,
    this.step = 1.0,
    required this.onChanged,
    this.label = '',
  });

  @override
  State<StandardStepper> createState() => _StandardStepperState();
}

class _StandardStepperState extends State<StandardStepper> {
  Timer? _timer;
  int _ticks = 0;

  void _startHold(bool increment) {
    _timer?.cancel();
    _ticks = 0;
    _performUpdate(increment);

    // Ajusta o intervalo para acelerar quanto mais tempo o usuário segurar
    _timer = Timer.periodic(const Duration(milliseconds: 300), (t) {
      _ticks++;
      _performUpdate(increment);

      if (_ticks == 5) {
        _timer?.cancel();
        // Aceleração média
        _timer = Timer.periodic(const Duration(milliseconds: 100), (t2) {
          _ticks++;
          _performUpdate(increment);

          if (_ticks == 15) {
            _timer?.cancel();
            // Aceleração máxima
            _timer = Timer.periodic(const Duration(milliseconds: 40), (t3) {
              _performUpdate(increment);
            });
          }
        });
      }
    });
  }

  void _stopHold() {
    _timer?.cancel();
    _timer = null;
  }

  void _performUpdate(bool increment) {
    final double nextVal = increment ? widget.value + widget.step : widget.value - widget.step;
    if (nextVal >= widget.min && nextVal <= widget.max) {
      widget.onChanged(nextVal);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayVal = widget.value.toStringAsFixed(
      widget.value.truncateToDouble() == widget.value ? 0 : 1
    );

    return Container(
      width: 170, // Tamanho padronizado entre 160px e 180px
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Decrementar
          GestureDetector(
            onTapDown: (_) => _startHold(false),
            onTapUp: (_) => _stopHold(),
            onTapCancel: () => _stopHold(),
            child: Container(
              width: 48,
              height: double.infinity,
              color: Colors.transparent,
              child: Icon(Icons.remove_rounded, color: AppColors.primary, size: 20),
            ),
          ),
          // Exibição do Valor
          Expanded(
            child: Center(
              child: Text(
                '$displayVal${widget.label.isNotEmpty ? " ${widget.label}" : ""}',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Incrementar
          GestureDetector(
            onTapDown: (_) => _startHold(true),
            onTapUp: (_) => _stopHold(),
            onTapCancel: () => _stopHold(),
            child: Container(
              width: 48,
              height: double.infinity,
              color: Colors.transparent,
              child: Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
```

#### B. Vertical DateTime Selector
Este componente substitui os popups nativos do sistema por uma interface em colunas roláveis/controladas com botões superiores (`+`) e inferiores (`-`) dedicados para ajustar valores (Hora, Minuto ou Dia, Mês, Ano), otimizado para o tema escuro.

##### Código de Referência para a Coluna Base (`VerticalSpinner`):
```dart
class VerticalSpinner extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String Function(int)? format;

  const VerticalSpinner({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.format,
  });

  @override
  State<VerticalSpinner> createState() => _VerticalSpinnerState();
}

class _VerticalSpinnerState extends State<VerticalSpinner> {
  Timer? _timer;
  int _ticks = 0;

  void _startHold(bool increment) {
    _timer?.cancel();
    _ticks = 0;
    _performUpdate(increment);

    _timer = Timer.periodic(const Duration(milliseconds: 300), (t) {
      _ticks++;
      _performUpdate(increment);

      if (_ticks == 5) {
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(milliseconds: 80), (t2) {
          _performUpdate(increment);
        });
      }
    });
  }

  void _stopHold() {
    _timer?.cancel();
    _timer = null;
  }

  void _performUpdate(bool increment) {
    int nextVal = increment ? widget.value + 1 : widget.value - 1;
    if (nextVal > widget.max) {
      nextVal = widget.min;
    } else if (nextVal < widget.min) {
      nextVal = widget.max;
    }
    widget.onChanged(nextVal);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayStr = widget.format != null
        ? widget.format!(widget.value)
        : widget.value.toString().padLeft(2, '0');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botão + (Top)
        GestureDetector(
          onTapDown: (_) => _startHold(true),
          onTapUp: (_) => _stopHold(),
          onTapCancel: () => _stopHold(),
          child: Container(
            width: 52,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.primary),
          ),
        ),
        // Valor (Center)
        Container(
          width: 52,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.symmetric(
              vertical: BorderSide(color: AppColors.border),
            ),
          ),
          child: Text(
            displayStr,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Botão - (Bottom)
        GestureDetector(
          onTapDown: (_) => _startHold(false),
          onTapUp: (_) => _stopHold(),
          onTapCancel: () => _stopHold(),
          child: Container(
            width: 52,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}
```

##### Seletores de Data e Hora Completos:
Ao envelopar as colunas base, implementam-se os seletores completos:
```dart
class VerticalTimeSelector extends StatelessWidget {
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  const VerticalTimeSelector({
    super.key,
    required this.time,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        VerticalSpinner(
          value: time.hour,
          min: 0,
          max: 23,
          onChanged: (h) => onChanged(TimeOfDay(hour: h, minute: time.minute)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(':', style: TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        VerticalSpinner(
          value: time.minute,
          min: 0,
          max: 59,
          onChanged: (m) => onChanged(TimeOfDay(hour: time.hour, minute: m)),
        ),
      ],
    );
  }
}
```
Para a data (`VerticalDateSelector`), o componente calcula dinamicamente o número máximo de dias do mês selecionado (`DateTime(year, month + 1, 0).day`), assegurando que transições de ano bissexto ou meses curtos (ex: Fevereiro) evitem datas impossíveis.
