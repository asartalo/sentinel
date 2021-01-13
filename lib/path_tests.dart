import 'package:path/path.dart' as p;
import 'dart:io';

final sep = Platform.pathSeparator;
final reg = RegExp('\\${sep}\\..+');
bool isHidden(String path, String rootPath) {
  // Strip rootPath
  final rootRelative = path.replaceFirst(rootPath, '');
  return reg.hasMatch(rootRelative);
}

var onlyPaths = <String>{'lib', 'test', 'integration_test'};
bool isIgnore(String path, String rootPath) {
  if (path == p.join(rootPath, 'integration_test', 'all_tests.dart')) {
    return true;
  }
  if (isHidden(path, rootPath) || isFunnyFile(path)) {
    return true;
  }
  return !onlyPaths.any((dir) => path.startsWith(p.join(rootPath, dir)));
}

final funnyReg = RegExp(r'[^A-Za-z]$');
bool isFunnyFile(String path) {
  return funnyReg.hasMatch(path);
}
