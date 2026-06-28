import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drift/drift.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/core_providers.dart';
import 'medication_model.dart';
import 'medication_api_client.dart';
import '../../pairing/presentation/pairing_notifier.dart';
import '../../pairing/domain/connection_state.dart';

part 'medication_repository.g.dart';

// Standalone parsing function for compute
List<MedicationModel> _parseMedicationsIsolate(Uint8List bytes) {
  final decompressed = GZipCodec().decode(bytes);
  final jsonString = utf8.decode(decompressed);
  final list = json.decode(jsonString) as List;
  return list.map((e) => MedicationModel.fromJson(e as Map<String, dynamic>)).toList();
}

// Standalone search function for compute (avoids main thread blocking on Levenshtein)
class SearchPayload {
  final List<MedicationModel> list;
  final String query;
  SearchPayload(this.list, this.query);
}

int _levenshteinDistance(String s1, String s2) {
  if (s1 == s2) return 0;
  if (s1.isEmpty) return s2.length;
  if (s2.isEmpty) return s1.length;

  final List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
  final List<int> v1 = List<int>.filled(s2.length + 1, 0);

  for (int i = 0; i < s1.length; i++) {
    v1[0] = i + 1;
    for (int j = 0; j < s2.length; j++) {
      final int cost = (s1[i] == s2[j]) ? 0 : 1;
      v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
    }
    for (int j = 0; j < v0.length; j++) {
      v0[j] = v1[j];
    }
  }
  return v0[s2.length];
}

List<MedicationModel> _searchIsolate(SearchPayload payload) {
  final q = payload.query.toLowerCase().trim();
  final db = payload.list;

  if (q.length < 2) return [];

  // Tier 1: Prefixo exato
  var results = db.where((m) => m.name.toLowerCase().startsWith(q)).toList();
  if (results.length >= 5) return results.take(20).toList();

  // Tier 2: Substring
  results = db.where((m) => m.name.toLowerCase().contains(q)).toList();
  if (results.length >= 3) return results.take(20).toList();

  // Tier 3: Levenshtein Fuzzy (tolerância max 3 edits)
  final fuzzyList = db
      .map((m) => MapEntry(m, _levenshteinDistance(q, m.name.toLowerCase())))
      .where((e) => e.value <= 3)
      .toList()
    ..sort((a, b) => a.value.compareTo(b.value));

  return fuzzyList.map((e) => e.key).take(20).toList();
}

class MedicationRepository {
  final AppDatabase _db;
  final MedicationApiClient _apiClient;
  final Ref _ref;
  List<MedicationModel> _medications = [];
  bool _isLoading = false;

  MedicationRepository(this._db, this._apiClient, this._ref);

  bool get isLoaded => _medications.isNotEmpty;
  bool get isLoading => _isLoading;

  bool _isConnected() {
    final connState = _ref.read(pairingNotifierProvider);
    return connState.status == ConnectionStatus.connected;
  }

  // ANVISA local search
  Future<void> loadDatabase() async {
    if (isLoaded || _isLoading) return;
    _isLoading = true;

    try {
      final byteData = await rootBundle.load('assets/medications_db.json.gz');
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      _medications = await compute(_parseMedicationsIsolate, bytes);
      debugPrint('ANVISA Medications database loaded: ${_medications.length} items.');
    } catch (e) {
      debugPrint('Error loading medications database: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<List<MedicationModel>> search(String query) async {
    if (!isLoaded) {
      await loadDatabase();
    }
    if (query.trim().length < 2) return [];

    return await compute(_searchIsolate, SearchPayload(_medications, query));
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
  }

  Future<void> deleteMedication(String name) async {
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
  final repo = MedicationRepository(
    ref.watch(databaseProvider),
    ref.watch(medicationApiClientProvider),
    ref,
  );
  // Pre-load in background
  repo.loadDatabase();
  return repo;
}
