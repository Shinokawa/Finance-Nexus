import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<File> resolveApplicationDatabaseFile() async {
  final dbDirectory = await getApplicationDocumentsDirectory();
  return File(p.join(dbDirectory.path, 'quant_hub.sqlite'));
}
