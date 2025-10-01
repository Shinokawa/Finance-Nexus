import 'dart:io';

Future<File> resolveApplicationDatabaseFile() {
  return Future<File>.error(
    UnsupportedError('AppDatabase() 在纯 Dart 环境不可用，请使用 AppDatabase.forFile'),
  );
}
