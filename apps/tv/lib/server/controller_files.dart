import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Unzips the controller web build into [into]. Entries that would leave
/// [into] (absolute paths, `..`) are skipped.
Future<Directory> extractControllerZip(Uint8List zip, Directory into) async {
  await into.create(recursive: true);
  for (final f in ZipDecoder().decodeBytes(zip)) {
    final name = f.name.replaceAll('\\', '/');
    if (!f.isFile || name.startsWith('/') || name.split('/').contains('..')) {
      continue;
    }
    final out = File('${into.path}/$name');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(f.content as List<int>);
  }
  return into;
}
