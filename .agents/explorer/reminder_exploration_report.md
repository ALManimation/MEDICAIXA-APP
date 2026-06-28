# Relatório de Análise — Gerenciar Lembrete (Quick Actions Bottom Sheet)

Este relatório detalha a exploração da estrutura do aplicativo MediCaixa e fornece a especificação técnica para a implementação do Bottom Sheet de ações rápidas ("Gerenciar Lembrete") ao tocar em um lembrete no painel (Dashboard).

---

## 1. Localização e Fluxo do Dashboard (UI)

* **Arquivo da UI do Dashboard**: `lib/features/dashboard/presentation/dashboard_screen.dart`
* **Seção de Lembretes**: Método `_buildRemindersSection(BuildContext context, DashboardState state, WidgetRef ref)` (linhas 456-513).
* **Mapeamento Atual**: Os lembretes ativos para o dia selecionado são exibidos em uma lista de cartões `ReminderCardWidget` mapeados a partir de `state.reminders` (linhas 496-509).

### Comportamento Atual de Toque (onTap)
Atualmente, o toque no cartão do lembrete redireciona diretamente o usuário para a tela de edição do formulário passando o lembrete selecionado como parâmetro:
```dart
onTap: () {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ReminderFormScreen(editReminder: reminder),
    ),
  );
}
```

### Ação de Conclusão Atual (onComplete)
O botão de check redondo no lado direito do cartão dispara diretamente o método `completeReminder` sem atualizar o estado visual do Dashboard de imediato de forma síncrona na UI:
```dart
onComplete: () => repo.completeReminder(reminder.id),
```

---

## 2. Modelos, Banco de Dados e Provedores de Lembretes

### Modelo do Lembrete (`ReminderModel`)
Definido em `lib/features/reminders/data/reminder_model.dart`.
* Contém atributos principais: `id`, `title`, `description`, `enabled`, `hasTime`, `hour`, `minute`, `period`, `interval`, `startDate`, `notifyDaysBefore`, `lastCompletedDate`, `color`, `lastModified`, e `pendingSync`.

### Tabela Drift do SQLite (`Reminders`)
Definida em `lib/core/database/database.dart`:
```dart
class Reminders extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  BoolColumn get enabled => boolean()();
  BoolColumn get hasTime => boolean()();
  IntColumn get hour => integer().nullable()();
  IntColumn get minute => integer().nullable()();
  TextColumn get period => text()();
  IntColumn get interval => integer()();
  TextColumn get startDate => text()();
  IntColumn get notifyDaysBefore => integer()();
  TextColumn get lastCompletedDate => text().nullable()();
  TextColumn get color => text()();
  IntColumn get lastModified => integer().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
```
* **Classes geradas pelo Drift**: A classe de dados gerada é `Reminder` (e a companion é `RemindersCompanion`).

### Provedores do Riverpod
Definido em `lib/features/reminders/data/reminder_repository.dart` via code generation:
```dart
@Riverpod(keepAlive: true)
ReminderRepository reminderRepository(ReminderRepositoryRef ref) {
  return ReminderRepository(
    ref.watch(databaseProvider),
    ref.watch(reminderApiClientProvider),
    ref,
  );
}
```
* A classe `DashboardNotifier` (em `dashboard_notifier.dart`) gerencia o estado geral da tela principal, incluindo a lista filtrada `state.reminders` atualizada através de `_reminderRepo.getAllReminders()` em conjunto com a validação de data `isReminderActiveOnDate`.

---

## 3. Conclusão e Registro de Evento de Histórico

A lógica de conclusão de lembretes é exposta pela função `completeReminder(int id)` na classe `ReminderRepository`:

### Processamento do Método `completeReminder`
1. **Localização**: Busca o registro local do lembrete no banco Drift.
2. **Formatação de Data**: Obtém a data no formato brasileiro (`DD/MM/YYYY`) usando `DateTime.now()` (Exemplo: `28/06/2026`).
3. **Atualização do Lembrete**: Salva o novo estado contendo a data formatada no campo `lastCompletedDate` e ajusta `pendingSync` para `true` se estiver offline (ou realiza chamada HTTP para a caixinha `_apiClient.completeReminder(id)` se estiver conectada).
4. **Inserção no Histórico de Eventos**: Utiliza o `historyRepositoryProvider` para registrar a conclusão do evento:
   ```dart
   final historyRepo = _ref.read(historyRepositoryProvider);
   await historyRepo.addHistoryEvent(
     reminderId: reminder.id,
     medName: reminder.title,
     status: 'CONCLUIDO',
     type: 'reminder',
   );
   ```
5. **Logs do Sistema**: Insere um log de sistema indicando que o lembrete foi concluído:
   ```dart
   await historyRepo.addSystemLog(
     level: 'INFO',
     message: 'Lembrete "${reminder.title}" marcado como Concluído',
     source: 'System',
   );
   ```

---

## 4. Exclusão de Lembrete

A lógica de exclusão é realizada pelo método `deleteReminder(int id)` em `ReminderRepository`:
1. Realiza chamada remota via `_apiClient.removeReminder(id)` se a caixinha estiver conectada à LAN (ESP32).
2. Remove o registro fisicamente da tabela local `reminders` no Drift SQLite:
   ```dart
   await (_db.delete(_db.reminders)..where((t) => t.id.equals(id))).go();
   ```

---

## 5. Tela de Edição / Formulário (`ReminderFormScreen`)

* **Localização**: `lib/features/reminders/presentation/reminder_form_screen.dart`
* **Definição do Widget**: É um widget `ConsumerStatefulWidget` com o seguinte construtor:
  ```dart
  const ReminderFormScreen({super.key, this.editReminder});
  ```
  onde `editReminder` é um parâmetro opcional do tipo `ReminderModel?`.
* **Navegação (Fluxo de Edição)**:
  ```dart
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ReminderFormScreen(editReminder: reminder),
    ),
  );
  ```

---

## 6. Padrões de Design, Regras de Negócio e Restrições Técnicas

### Regra de Ouro da Estilização (Rule 22)
* **Nunca utilizar `const` com `AppColors`**: Os campos de cores em `AppColors` são declarados como `static final Color` (não são constantes de compilação em Dart). Widgets como `Icon`, `TextStyle`, `BorderSide` ou `Divider` que recebem cores de `AppColors` **não** podem possuir o modificador `const`.

### Constantes de Cores Relevantes (`AppColors` em `lib/core/constants/app_colors.dart`)
* `background` = `Color(0xFF111827)` (Fundo principal Dark)
* `surface` = `Color(0xFF1F2937)` (Fundo dos cards e do modal)
* `border` = `Color(0xFF374151)` (Bordas divisórias)
* `primary` = `Color(0xFF34D399)` (Destaques e botões de ação positiva)
* `success` = `Color(0xFF10B981)` (Feedback de sucesso e marcação de concluído)
* `missed` = `Color(0xFFEF4444)` (Ações de perigo, exclusão ou falha)
* `textMuted` = `Color(0xFF9CA3AF)` (Texto secundário e labels de apoio)

### Respeito à Hierarquia Drift (Rule 23)
* O Drift gera classes de dados omitindo o sufixo "Data". Portanto, a tabela `Reminders` gera o objeto de dados singular plano chamado `Reminder`. Não se deve utilizar `ReminderData`.

### Sincronismo de Refresh de Estado do Dashboard (Riverpod)
* O DashboardNotifier utiliza um método de carregamento offline que lê o banco de dados via chamadas assíncronas do Future (`getAllReminders`). 
* **Importante**: Após concluir, excluir ou alternar a ativação de um lembrete pelas ações do Bottom Sheet, é **obrigatório** invocar o refresh do dashboard notifier para forçar a reconstrução da UI:
  ```dart
  ref.read(dashboardNotifierProvider.notifier).refresh();
  ```

---

## 7. Proposta de Design para o Bottom Sheet de Lembretes

Para manter a harmonia visual com o `SnoozeModal` dos alarmes, o Bottom Sheet para lembretes (`ReminderActionsModal`) deve adotar o seguinte layout:

```dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../reminders/data/reminder_model.dart';
import '../../reminders/data/reminder_repository.dart';
import '../../reminders/presentation/reminder_form_screen.dart';
import '../../dashboard/presentation/dashboard_notifier.dart';

class ReminderActionsModal extends StatelessWidget {
  final ReminderModel reminder;
  final ReminderRepository repository;
  final VoidCallback onRefresh;

  const ReminderActionsModal({
    super.key,
    required this.reminder,
    required this.repository,
    required this.onRefresh,
  });

  static Future<void> show(
    BuildContext context, {
    required ReminderModel reminder,
    required ReminderRepository repository,
    required VoidCallback onRefresh,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReminderActionsModal(
        reminder: reminder,
        repository: repository,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hexColor = AppColors.getAlarmColor(reminder.color);
    final todayFormatted = "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}";
    final isDone = reminder.lastCompletedDate == todayFormatted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de arraste superior do modal
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Text(
            'Gerenciar Lembrete',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),

          // Título do Lembrete com Indicador de Cor
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hexColor,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  reminder.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Botão Ativar / Desativar
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await repository.toggleReminder(reminder.id, !reminder.enabled);
                onRefresh();
                if (context.mounted) Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: reminder.enabled ? AppColors.missed : AppColors.success,
                side: BorderSide(
                  color: reminder.enabled 
                      ? AppColors.missed.withValues(alpha: 0.5) 
                      : AppColors.success.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(
                reminder.enabled 
                    ? Icons.pause_circle_outline_rounded 
                    : Icons.play_circle_outline_rounded,
                size: 20,
              ),
              label: Text(
                reminder.enabled ? 'Desativar Lembrete' : 'Ativar Lembrete',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Botão "Concluir Lembrete" (exibido apenas se não estiver feito hoje)
          if (!isDone) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await repository.completeReminder(reminder.id);
                  onRefresh();
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: const Text('Concluir Lembrete', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Divider(color: AppColors.border),
          const SizedBox(height: 12),

          // Linha de ações de Edição e Exclusão
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Fecha bottom sheet
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReminderFormScreen(editReminder: reminder),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Editar', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: Text('Excluir Lembrete', style: TextStyle(color: AppColors.text)),
                        content: Text('Tem certeza que deseja excluir "${reminder.title}"?', style: TextStyle(color: AppColors.textMuted)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(foregroundColor: AppColors.missed),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await repository.deleteReminder(reminder.id);
                      onRefresh();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.missed,
                    side: BorderSide(color: AppColors.missed.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.delete_rounded, size: 18),
                  label: const Text('Excluir', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### Alterações Recomendadas no `DashboardScreen` (`dashboard_screen.dart`):
A propriedade `onTap` e `onComplete` passadas para `ReminderCardWidget` no método `_buildRemindersSection` devem ser alteradas para:
```dart
onComplete: () async {
  await repo.completeReminder(reminder.id);
  ref.read(dashboardNotifierProvider.notifier).refresh();
},
onTap: () {
  ReminderActionsModal.show(
    context,
    reminder: reminder,
    repository: repo,
    onRefresh: () => ref.read(dashboardNotifierProvider.notifier).refresh(),
  );
},
```
Isso garante a sincronização completa do estado do Dashboard e abre o modal em vez de ir direto ao formulário.
