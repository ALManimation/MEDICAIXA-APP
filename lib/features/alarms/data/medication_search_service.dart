import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'medication_search_service.g.dart';

// Represents a Medication from the JSON DB
class MedicationAnvisa {
  final String name;
  final String type;
  final String dosage;
  final String generic;

  MedicationAnvisa({
    required this.name,
    required this.type,
    required this.dosage,
    required this.generic,
  });

  factory MedicationAnvisa.fromJson(Map<String, dynamic> json) {
    return MedicationAnvisa(
      name: json['n'] ?? '',
      type: json['t'] ?? '',
      dosage: json['d'] ?? '',
      generic: json['g'] ?? '',
    );
  }
}

class MedicationSearchService {
  List<MedicationAnvisa>? _cachedDb;

  // Loads and decodes the DB in an isolate
  Future<void> _loadDb() async {
    if (_cachedDb != null) return;
    
    // Read the gzipped file bytes on the main thread (rootBundle is easily accessible here)
    final bytes = await rootBundle.load('assets/medications_db.json.gz');
    final uint8list = bytes.buffer.asUint8List();

    // Spawn isolate to decompress and parse JSON
    _cachedDb = await compute(_parseMedicationsGz, uint8list);
  }

  static List<MedicationAnvisa> _parseMedicationsGz(Uint8List bytes) {
    // 1. Decompress GZIP
    final decompressed = gzip.decode(bytes);
    // 2. Decode UTF-8
    final jsonString = utf8.decode(decompressed);
    // 3. Parse JSON
    final List<dynamic> jsonList = jsonDecode(jsonString);
    // 4. Map to objects
    return jsonList.map((j) => MedicationAnvisa.fromJson(j as Map<String, dynamic>)).toList();
  }

  // Searches the DB in an isolate
  Future<List<MedicationAnvisa>> search(String query) async {
    if (query.trim().length < 2) return [];
    
    await _loadDb();
    
    if (_cachedDb == null || _cachedDb!.isEmpty) return [];

    // Run the actual string matching in an isolate to prevent UI stutter for large lists
    final result = await compute(
      _searchInIsolate,
      _SearchParam(_cachedDb!, query.trim().toLowerCase()),
    );
    
    return result;
  }
  // Returns all unique dosages for a given medication name
  Future<List<String>> getDosagesForMedication(String name) async {
    if (name.trim().isEmpty) return [];
    await _loadDb();
    if (_cachedDb == null || _cachedDb!.isEmpty) return [];
    
    final normalizedName = _removeAccents(name.trim().toLowerCase());
    final matches = _cachedDb!.where((med) => _removeAccents(med.name.trim().toLowerCase()) == normalizedName);
    
    // Extract unique dosages, filter out empty ones
    final dosages = matches
        .map((m) => m.dosage.trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();
    
    return dosages;
  }
}

class _SearchParam {
  final List<MedicationAnvisa> db;
  final String query;
  _SearchParam(this.db, this.query);
}

String _removeAccents(String str) {
  var withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
  var withoutDia = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
  for (int i = 0; i < withDia.length; i++) {
    str = str.replaceAll(withDia[i], withoutDia[i]);
  }
  return str;
}

int _levenshtein(String a, String b) {
  if (a.length == 0) return b.length;
  if (b.length == 0) return a.length;

  var v0 = List<int>.filled(b.length + 1, 0);
  var v1 = List<int>.filled(b.length + 1, 0);

  for (int i = 0; i <= b.length; i++) v0[i] = i;

  for (int i = 0; i < a.length; i++) {
    v1[0] = i + 1;
    for (int j = 0; j < b.length; j++) {
      int cost = (a[i] == b[j]) ? 0 : 1;
      v1[j + 1] = (v1[j] + 1 < v0[j + 1] + 1 ? v1[j] + 1 : v0[j + 1] + 1);
      if (v0[j] + cost < v1[j + 1]) {
        v1[j + 1] = v0[j] + cost;
      }
    }
    for (int j = 0; j <= b.length; j++) v0[j] = v1[j];
  }
  return v1[b.length];
}

List<MedicationAnvisa> _searchInIsolate(_SearchParam param) {
  final q = _removeAccents(param.query.toLowerCase());
  
  final nameStartsWith = <MedicationAnvisa>[];
  final nameContains = <MedicationAnvisa>[];
  final fuzzyNameMatches = <MedicationAnvisa>[];
  final genericStartsWith = <MedicationAnvisa>[];
  final genericContains = <MedicationAnvisa>[];
  final fuzzyGenericMatches = <MedicationAnvisa>[];

  for (var med in param.db) {
    final n = _removeAccents(med.name.toLowerCase());
    final g = _removeAccents(med.generic.toLowerCase());

    bool matched = false;
    if (n.startsWith(q)) {
      nameStartsWith.add(med);
      matched = true;
    } else if (n.contains(q)) {
      nameContains.add(med);
      matched = true;
    } else if (g.startsWith(q)) {
      genericStartsWith.add(med);
      matched = true;
    } else if (g.contains(q)) {
      genericContains.add(med);
      matched = true;
    }

    // Busca aproximada se a query for maior que 4 caracteres e não deu match exato
    if (!matched && q.length >= 4) {
      // Pega a primeira palavra do nome para comparar
      final firstWord = n.split(' ').first;
      if (firstWord.length >= q.length - 2 && firstWord.length <= q.length + 2) {
        if (_levenshtein(q, firstWord) <= 2) {
          fuzzyNameMatches.add(med);
          matched = true;
        }
      }
      
      if (!matched) {
        // Tenta também com a primeira palavra do genérico
        final genericFirstWord = g.split(' ').first;
        if (genericFirstWord.length >= q.length - 2 && genericFirstWord.length <= q.length + 2) {
          if (_levenshtein(q, genericFirstWord) <= 2) {
            fuzzyGenericMatches.add(med);
          }
        }
      }
    }
  }

  // Helper para ordenar por tamanho e depois alfabeticamente
  int compareMatches(MedicationAnvisa a, MedicationAnvisa b, bool byGeneric) {
    final strA = byGeneric ? a.generic : a.name;
    final strB = byGeneric ? b.generic : b.name;
    if (strA.length != strB.length) {
      return strA.length.compareTo(strB.length);
    }
    return _removeAccents(strA.toLowerCase()).compareTo(_removeAccents(strB.toLowerCase()));
  }

  nameStartsWith.sort((a, b) => compareMatches(a, b, false));
  nameContains.sort((a, b) => compareMatches(a, b, false));
  fuzzyNameMatches.sort((a, b) => compareMatches(a, b, false));
  
  genericStartsWith.sort((a, b) => compareMatches(a, b, true));
  genericContains.sort((a, b) => compareMatches(a, b, true));
  fuzzyGenericMatches.sort((a, b) => compareMatches(a, b, true));

  final combined = [
    ...nameStartsWith,
    ...nameContains,
    ...fuzzyNameMatches,
    ...genericStartsWith,
    ...genericContains,
    ...fuzzyGenericMatches,
  ];

  return combined.take(30).toList();
}

@riverpod
MedicationSearchService medicationSearchService(Ref ref) {
  return MedicationSearchService();
}

@riverpod
Future<List<MedicationAnvisa>> searchMedications(Ref ref, String query) async {
  final service = ref.watch(medicationSearchServiceProvider);
  return service.search(query);
}

@riverpod
Future<List<String>> medicationDosages(Ref ref, String medicationName) async {
  final service = ref.watch(medicationSearchServiceProvider);
  return service.getDosagesForMedication(medicationName);
}

