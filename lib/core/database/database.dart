import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Alarms extends Table {
  IntColumn get id => integer()();
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();
  TextColumn get name => text()();
  TextColumn get medName => text()();
  BoolColumn get enabled => boolean()();
  BoolColumn get active => boolean()();
  TextColumn get days => text()(); // JSON serialized List<bool>
  TextColumn get status => text()(); // PENDENTE, TOMANDO, SNOOZED
  TextColumn get color => text()();
  RealColumn get quantity => real()();
  TextColumn get daysQuantity => text()(); // JSON serialized List<double>
  TextColumn get type => text()();
  TextColumn get dosage => text().nullable()();
  TextColumn get lastStatus => text().nullable()();
  TextColumn get lastStatusDate => text().nullable()();
  IntColumn get snoozeMin => integer()();
  TextColumn get startDate => text().nullable()();
  IntColumn get durationDays => integer()();
  TextColumn get createdDate => text().nullable()();

  // Advanced fields (optional)
  IntColumn get cycleOnDays => integer().nullable()();
  IntColumn get cycleOffDays => integer().nullable()();
  IntColumn get cycleCurrentDay => integer().nullable()();
  BoolColumn get cycleIsPaused => boolean().nullable()();

  BoolColumn get isPrn => boolean().nullable()();
  IntColumn get prnMinIntervalHours => integer().nullable()();
  IntColumn get prnMaxDailyDoses => integer().nullable()();
  IntColumn get prnDosesToday => integer().nullable()();

  IntColumn get pauseUntil => integer().nullable()();

  BoolColumn get isDynamic => boolean().nullable()();
  TextColumn get dynamicInstruction => text().nullable()();

  IntColumn get taperStageCount => integer().nullable()();
  IntColumn get taperCurrentStage => integer().nullable()();
  IntColumn get taperDayInStage => integer().nullable()();
  TextColumn get taperStages => text().nullable()(); // JSON serialized List<TaperStage>
  BoolColumn get taperLoop => boolean().nullable()();

  TextColumn get specialInstruction => text().nullable()();

  RealColumn get adjustStep => real().nullable()();
  IntColumn get adjustIntervalDays => integer().nullable()();
  RealColumn get adjustLimit => real().nullable()();

  BoolColumn get requiresRemoval => boolean().nullable()();
  IntColumn get removalDelayMins => integer().nullable()();
  TextColumn get siteRotationList => text().nullable()();
  IntColumn get currentSiteIndex => integer().nullable()();

  IntColumn get dayOfMonth => integer().nullable()();
  IntColumn get groupId => integer().nullable()();
  IntColumn get intervalHours => integer().nullable()();

  // Local Sync Fields
  IntColumn get lastModified => integer().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Reminders extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  BoolColumn get enabled => boolean()();
  BoolColumn get hasTime => boolean()();
  IntColumn get hour => integer().nullable()();
  IntColumn get minute => integer().nullable()();
  TextColumn get period => text()(); // day, week, month, year, "" (once)
  IntColumn get interval => integer()();
  TextColumn get startDate => text()();
  IntColumn get notifyDaysBefore => integer()();
  TextColumn get lastCompletedDate => text().nullable()();
  TextColumn get color => text()();

  // Local Sync Fields
  IntColumn get lastModified => integer().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get deviceIp => text().nullable()();
  TextColumn get patientName => text().withDefault(const Constant("Paciente"))();
  IntColumn get speakerVolume => integer().withDefault(const Constant(20))();
  IntColumn get brightness => integer().withDefault(const Constant(50))();
  TextColumn get language => text().withDefault(const Constant("pt"))();
  TextColumn get wakeWord => text().withDefault(const Constant("jarvis"))();
  IntColumn get alarmSound => integer().withDefault(const Constant(0))();
  IntColumn get alarmSpacingMs => integer().withDefault(const Constant(10000))();
  BoolColumn get alarmWizardEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get sleepTime => text().nullable()();
  TextColumn get wakeTime => text().nullable()();
  BoolColumn get sleepScheduleEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get breakfastTime => text().nullable()();
  TextColumn get lunchTime => text().nullable()();
  TextColumn get dinnerTime => text().nullable()();
  TextColumn get geminiApiKey => text().nullable()();
  TextColumn get prohibitedRanges => text().nullable()(); // JSON serialized List<TimeRange>

  @override
  Set<Column> get primaryKey => {id};
}

class HistoryEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get alarmId => integer().nullable()();
  IntColumn get reminderId => integer().nullable()();
  TextColumn get medName => text().nullable()();
  TextColumn get dosage => text().nullable()();
  IntColumn get timestamp => integer()();
  TextColumn get status => text()(); // TOMADO, PERDIDO, SNOOZED, CONCLUIDO
  TextColumn get type => text()(); // alarm, reminder, system
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
}

class SystemLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get timestamp => integer()();
  TextColumn get level => text()(); // INFO, WARNING, ERROR, DEBUG
  TextColumn get message => text()();
  TextColumn get source => text()(); // System, ESP32, WiFi, Database, API
}

@DriftDatabase(tables: [Alarms, Reminders, Settings, HistoryEvents, SystemLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.createTable(historyEvents);
            await migrator.createTable(systemLogs);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'medicaixa.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
