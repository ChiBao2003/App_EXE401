import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Durable snapshots of pending requests. The caller serializes read/modify/write.
/// A failed read must throw: treating a damaged snapshot as empty would lose data.
class PomodoroOutbox {
  final Future<Directory> Function() _directory;

  PomodoroOutbox({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  Future<File> _file() async =>
      File('${(await _directory()).path}/pomodoro_outbox.json');

  Future<List<String>> read() async {
    final file = await _file();
    if (!await file.exists()) return [];
    return (jsonDecode(await file.readAsString()) as List).cast<String>();
  }

  Future<bool> write(List<String> entries) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final staging = File('${file.path}.tmp');
    final encoded = jsonEncode(entries);
    // Leave the previous snapshot intact if writing/flushing fails.
    await staging.writeAsString(encoded, flush: true);
    await staging.rename(file.path);
    return await file.readAsString() == encoded;
  }
}
