import '../../../core/network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/database/database.dart';

part 'medication_api_client.g.dart';

class MedicationApiClient {
  final DioClient _dioClient;

  MedicationApiClient(this._dioClient);

  Future<List<Medication>> fetchMedications() async {
    final response = await _dioClient.get('/meds_list');
    if (response.statusCode == 200) {
      final List data = response.data is List ? response.data : [];
      return data.map((json) {
        return Medication(
          name: json['name'] as String? ?? '',
          color: json['color'] as String? ?? 'white',
          type: json['type'] as String? ?? 'comprimido',
          dosage: json['dosage'] as String?,
          pendingSync: false,
        );
      }).toList();
    }
    throw Exception('Failed to load medications from ESP32');
  }

  Future<void> addMedication(Medication med) async {
    await _dioClient.post(
      '/meds_add',
      data: {
        'name': med.name,
        'color': med.color,
        'type': med.type,
        'dosage': med.dosage ?? '',
      },
    );
  }

  Future<void> updateMedication(String oldName, Medication med) async {
    await _dioClient.post(
      '/meds_update',
      data: {
        'old_name': oldName,
        'new_name': med.name,
        'color': med.color,
        'type': med.type,
        'dosage': med.dosage ?? '',
      },
    );
  }

  Future<void> removeMedication(String name) async {
    await _dioClient.post(
      '/meds_remove',
      data: {
        'name': name,
      },
    );
  }
}

@Riverpod(keepAlive: true)
MedicationApiClient medicationApiClient(MedicationApiClientRef ref) {
  return MedicationApiClient(ref.watch(dioClientProvider));
}
