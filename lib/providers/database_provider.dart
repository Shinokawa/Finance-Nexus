import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';

typedef AppDbRef = Ref<AppDatabase>;

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
