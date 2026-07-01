import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drift/drift.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/core_providers.dart';
import 'medication_model.dart';
import 'medication_api_client.dart';
import '../../../core/providers/connection_providers.dart';
import '../../pairing/domain/connection_state.dart';
import '../../alarms/data/medication_search_service.dart';

part 'medication_repository.g.dart';

class MedicationRepository {
  final AppDatabase _db;
  final MedicationApiClient _apiClient;
  final Ref _ref;

  MedicationRepository(this._db, this._apiClient, this._ref);

  bool _isConnected() {
    final connState = _ref.read(deviceConnectionStateProvider);
    return connState.status == ConnectionStatus.connected;
  }

  Future<List<MedicationModel>> search(String query) async {
    if (query.trim().length < 2) return [];

    final searchService = _ref.read(medicationSearchServiceProvider);
    final results = await searchService.search(query);
    return results.map((anvisa) => MedicationModel(
      name: anvisa.name,
      type: anvisa.type.isNotEmpty ? anvisa.type : 'comprimido',
      dosage: anvisa.dosage,
      generic: anvisa.generic,
    )).toList();
  }

  // Saved Medications Drift local & ESP32 CRUD
  Stream<List<Medication>> watchAllMedications() {
    return (_db.select(_db.medications)
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)
          ]))
        .watch();
  }

  Future<List<Medication>> getAllMedications() async {
    return await (_db.select(_db.medications)
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)
          ]))
        .get();
  }

  Future<Medication?> getMedicationByName(String name) async {
    return await (_db.select(_db.medications)..where((t) => t.name.equals(name))).getSingleOrNull();
  }

  Future<void> createMedication(Medication med) async {
    bool isPending = false;

    if (_isConnected()) {
      try {
        await _apiClient.addMedication(med);
      } catch (e) {
        debugPrint('Error sending medication to ESP32: $e. Saving offline.');
        isPending = true;
      }
    } else {
      isPending = true;
    }

    final newMed = med.copyWith(
      lastModified: Value(DateTime.now().millisecondsSinceEpoch),
      pendingSync: isPending,
    );

    await _db.into(_db.medications).insert(newMed, mode: InsertMode.insertOrReplace);

    // Bidirectional color sync
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.alarms)..where((t) => t.medName.equals(med.name))).write(
      AlarmsCompanion(
        color: Value(med.color),
        pendingSync: const Value(true),
        lastModified: Value(nowMs),
      ),
    );
  }

  Future<void> updateMedication(String oldName, Medication med) async {
    bool isPending = false;

    if (_isConnected()) {
      try {
        await _apiClient.updateMedication(oldName, med);
      } catch (e) {
        debugPrint('Error updating medication on ESP32: $e. Marking pending.');
        isPending = true;
      }
    } else {
      isPending = true;
    }

    if (oldName != med.name) {
      await (_db.delete(_db.medications)..where((t) => t.name.equals(oldName))).go();
    }

    final updatedMed = med.copyWith(
      lastModified: Value(DateTime.now().millisecondsSinceEpoch),
      pendingSync: isPending,
    );

    await _db.into(_db.medications).insert(updatedMed, mode: InsertMode.insertOrReplace);

    // Bidirectional color sync
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.alarms)..where((t) => t.medName.equals(med.name))).write(
      AlarmsCompanion(
        color: Value(med.color),
        pendingSync: const Value(true),
        lastModified: Value(nowMs),
      ),
    );
  }

  Future<void> deleteMedication(String name) async {
    final activeAlarms = await (_db.select(_db.alarms)
          ..where((t) => (t.medName.equals(name) | t.name.equals(name)) & (t.enabled.equals(true) | t.active.equals(true))))
        .get();
    if (activeAlarms.isNotEmpty) {
      throw Exception('Cannot delete medication in use by active/enabled alarms.');
    }

    if (_isConnected()) {
      try {
        await _apiClient.removeMedication(name);
      } catch (e) {
        debugPrint('Error removing medication on ESP32: $e');
      }
    }
    await (_db.delete(_db.medications)..where((t) => t.name.equals(name))).go();
  }

  Future<void> syncWithDevice() async {
    if (!_isConnected()) return;

    try {
      final remoteMeds = await _apiClient.fetchMedications();
      final localMeds = await getAllMedications();

      final remoteMap = {for (final m in remoteMeds) m.name: m};

      // 1. Upload offline modifications
      for (final local in localMeds) {
        if (local.pendingSync) {
          try {
            await _apiClient.addMedication(local);
            await _db.update(_db.medications).replace(
                  local.copyWith(pendingSync: false),
                );
          } catch (e) {
            debugPrint('Failed to upload medication ${local.name}: $e');
          }
        }
      }

      // Re-fetch local list
      final updatedLocalMeds = await getAllMedications();
      final updatedLocalMap = {for (final m in updatedLocalMeds) m.name: m};

      // 2. Pull remote updates
      for (final remote in remoteMeds) {
        final local = updatedLocalMap[remote.name];
        if (local == null) {
          await _db.into(_db.medications).insert(remote);
        } else if (!local.pendingSync) {
          await _db.update(_db.medications).replace(remote);
        }
      }

      // 3. Clean up deleted medications
      for (final local in updatedLocalMeds) {
        if (!remoteMap.containsKey(local.name) && !local.pendingSync) {
          final activeAlarms = await (_db.select(_db.alarms)
                ..where((t) => (t.medName.equals(local.name) | t.name.equals(local.name)) & (t.enabled.equals(true) | t.active.equals(true))))
              .get();
          if (activeAlarms.isNotEmpty) {
            debugPrint('Warning: Skipped database deletion for medication "${local.name}" because it is referenced by active/enabled alarms.');
            continue;
          }
          await (_db.delete(_db.medications)..where((t) => t.name.equals(local.name))).go();
        }
      }
    } catch (e) {
      debugPrint('Error syncing medications: $e');
    }
  }

  Future<void> loadBackupFixture(List<dynamic> list) async {
    try {
      await _db.delete(_db.medications).go();
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final med = Medication(
            name: item['name'] as String? ?? item['med_name'] as String? ?? '',
            color: item['color'] as String? ?? 'white',
            type: item['type'] as String? ?? 'comprimido',
            dosage: item['dosage'] as String?,
            pendingSync: false,
          );
          await _db.into(_db.medications).insert(med, mode: InsertMode.insertOrReplace);
        }
      }
    } catch (e) {
      debugPrint('Error loading medications backup fixture: $e');
    }
  }
}

@Riverpod(keepAlive: true)
MedicationRepository medicationRepository(MedicationRepositoryRef ref) {
  return MedicationRepository(
    ref.watch(databaseProvider),
    ref.watch(medicationApiClientProvider),
    ref,
  );
}
