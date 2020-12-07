import 'dart:io';

final sep = Platform.pathSeparator;
final reg = RegExp('\\${sep}\\..+');
bool isHidden(String path, String rootPath) {
  // Strip rootPath
  final rootRelative = path.replaceFirst(rootPath, '');
  return reg.hasMatch(rootRelative);
}

var onlyPaths = <String>{'lib', 'test'};
bool isIgnore(String path, String rootPath) {
  if (isHidden(path, rootPath)) {
    return true;
  }
  return !onlyPaths.any((dir) => path.startsWith('$rootPath${sep}$dir'));
}

final funnyReg = RegExp(r'[^A-Za-z]$');
bool isFunnyFile(String path) {
  return funnyReg.hasMatch(path);
}
