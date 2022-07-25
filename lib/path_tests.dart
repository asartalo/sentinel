import 'dart:io';

import 'package:glob/glob.dart';
import 'project.dart';

final sep = Platform.pathSeparator;
final reg = RegExp('\\$sep\\..+');
bool isHidden(String path, String rootPath) {
  // Strip rootPath
  final rootRelative = path.replaceFirst(rootPath, '');
  return reg.hasMatch(rootRelative);
}

final onlyPaths = <String>{'lib', 'test', 'integration_test'};

final Map<String, Glob> _globCache = {};

Glob getGlob(String globString) {
  final cached = _globCache[globString];
  if (cached is Glob) {
    return cached;
  }
  final glob = Glob(globString);
  _globCache[globString] = glob;
  return glob;
}

Future<bool> isIgnore(String path, Project project) async {
  final join = project.fs.path.join;
  final rootPath = project.rootPath;
  if (path == project.allIntegrationTestFilePath) {
    return true;
  }

  if (isHidden(path, rootPath) || isFunnyFile(path)) {
    return true;
  }

  final ignoredPaths = await project.ignoredPaths();
  for (final ignorePath in ignoredPaths) {
    final fullPath = project.fs.path.join(project.rootPath, ignorePath);
    final glob = getGlob(fullPath);
    if (glob.matches(path)) {
      return true;
    }
  }

  return !onlyPaths.any((dir) => path.startsWith(join(rootPath, dir)));
}

final funnyReg = RegExp(r'[^A-Za-z]$');
bool isFunnyFile(String path) {
  return funnyReg.hasMatch(path);
}
