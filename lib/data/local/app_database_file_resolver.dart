import 'dart:io';

import 'app_database_file_resolver_stub.dart'
    if (dart.library.ui) 'app_database_file_resolver_flutter.dart'
    as resolver;

Future<File> resolveApplicationDatabaseFile() {
  return resolver.resolveApplicationDatabaseFile();
}
