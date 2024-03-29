import 'dart:async';
import 'dart:io';

import 'package:file/local.dart';
import 'package:sentinel/printer.dart';
import 'package:sentinel/project.dart';
import 'package:sentinel/sentinel_front.dart';
import 'package:sentinel/sentinel_runner.dart';

const fs = LocalFileSystem();
final printer = TruePrinter(stderr: stderr, stdout: stdout);
final sep = Platform.pathSeparator;

// ignore_for_file: avoid_print
Future<void> main(List<String> arguments) async {
  exitCode = 0;
  stdout.encoding = const SystemEncoding();
  final front = SentinelFront();

  try {
    final result = front.parse(arguments);
    if (result.command == Command.help) {
      printer.println(front.helpText());
      return;
    }
    if (result.command == Command.version) {
      printer.println(front.version());
      return;
    }
    final fullPath = await getCanonicalPath(result.directory);
    final project = Project(fullPath, fs);
    final runner = SentinelRunner(project: project, printer: printer, sep: sep);

    await runner.watchDirectory(
      noIntegration: !result.integration,
      device: result.device,
    );
  } catch (e) {
    exitCode = 1;
    printer.printErr(e.toString());
    return;
  }
}

Future<String> getCanonicalPath(String dir) async {
  if (dir.isNotEmpty && !(await fs.isDirectory(dir))) {
    throw Exception('Error: Path "$dir" is not a directory');
  }
  return fs.path.canonicalize(dir.isEmpty ? fs.currentDirectory.path : dir);
}
