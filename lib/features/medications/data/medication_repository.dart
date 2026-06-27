import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'medication_model.dart';

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

  List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
  List<int> v1 = List<int>.filled(s2.length + 1, 0);

  for (int i = 0; i < s1.length; i++) {
    v1[0] = i + 1;
    for (int j = 0; j < s2.length; j++) {
      int cost = (s1[i] == s2[j]) ? 0 : 1;
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
  List<MedicationModel> _medications = [];
  bool _isLoading = false;

  bool get isLoaded => _medications.isNotEmpty;
  bool get isLoading => _isLoading;

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
      debugPrint("ANVISA Medications database loaded: ${_medications.length} items.");
    } catch (e) {
      debugPrint("Error loading medications database: $e");
    } finally {
      _isLoading = false;
    }
  }

  Future<List<MedicationModel>> search(String query) async {
    if (!isLoaded) {
      await loadDatabase();
    }
    if (query.trim().length < 2) return [];

    // Run search in compute isolate to keep UI smooth
    return await compute(_searchIsolate, SearchPayload(_medications, query));
  }
}

@Riverpod(keepAlive: true)
MedicationRepository medicationRepository(MedicationRepositoryRef ref) {
  final repo = MedicationRepository();
  // Pre-load in background
  repo.loadDatabase();
  return repo;
}
