import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/database.dart';
import '../network/dio_client.dart';

part 'core_providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase database(DatabaseRef ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
}

@Riverpod(keepAlive: true)
DioClient dioClient(DioClientRef ref) {
  return DioClient();
}
