import 'dart:io';
import 'package:path/path.dart' as p;

class TestFileMatch {
  final bool exists;
  final String path;
  TestFileMatch({this.exists, this.path});
}

final sep = Platform.pathSeparator;
final testReg = RegExp(r'_test.dart$');
final libDartReg = RegExp(r'lib[\/\\].+\.dart$');
TestFileMatch findMatchingTest(String path, String rootPath) {
  if (testReg.hasMatch(path)) {
    return TestFileMatch(exists: true, path: path);
  }
  if (libDartReg.hasMatch(path)) {
    var fromLibPath = path.replaceFirst('${rootPath}${sep}lib${sep}', '');
    var testEquivalent = p.join(
        rootPath, 'test', fromLibPath.replaceFirst('.dart', '_test.dart'));
    if (FileSystemEntity.typeSync(testEquivalent) !=
        FileSystemEntityType.notFound) {
      return TestFileMatch(exists: true, path: testEquivalent);
    }
  }
  return TestFileMatch(exists: false, path: '');
}
