import 'dart:io';

import 'package:sentinel/project.dart';

final sep = Platform.pathSeparator;
final reg = RegExp('\\${sep}\\..+');
bool isHidden(String path, String rootPath) {
  // Strip rootPath
  final rootRelative = path.replaceFirst(rootPath, '');
  return reg.hasMatch(rootRelative);
}

var onlyPaths = <String>{'lib', 'test', 'integration_test'};
// ignore: todo
// TODO: Refactor this one
bool isIgnore(String path, Project project) {
  final join = project.fs.path.join;
  final rootPath = project.rootPath;
  if (path == join(rootPath, 'integration_test', 'all_tests.dart')) {
    return true;
  }
  if (isHidden(path, rootPath) || isFunnyFile(path)) {
    return true;
  }
  return !onlyPaths.any((dir) => path.startsWith(join(rootPath, dir)));
}

final funnyReg = RegExp(r'[^A-Za-z]$');
bool isFunnyFile(String path) {
  return funnyReg.hasMatch(path);
}
