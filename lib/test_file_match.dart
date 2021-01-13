import 'dart:io';
import 'package:path/path.dart' as p;

class TestFileMatch {
  final bool exists;
  final String path;
  final bool integrationTest;
  TestFileMatch({this.exists, this.path, this.integrationTest = false});

  @override
  String toString() {
    return 'path: $path,\nexists: $exists\nintegrationTest: $integrationTest';
  }
}

final sep = Platform.pathSeparator;
final testReg = RegExp(r'_test.dart$');
final libDartReg = RegExp(r'lib[\/\\].+\.dart$');
TestFileMatch findMatchingTest(String path, String rootPath) {
  if (testReg.hasMatch(path)) {
    final integrationTest =
        path.startsWith(p.join(rootPath, 'integration_test'));
    return TestFileMatch(
      exists: true,
      path: path,
      integrationTest: integrationTest,
    );
  }
  if (libDartReg.hasMatch(path)) {
    final fromLibPath = path.replaceFirst('${rootPath}${sep}lib${sep}', '');
    final testEquivalent = p.join(
        rootPath, 'test', fromLibPath.replaceFirst('.dart', '_test.dart'));
    if (FileSystemEntity.typeSync(testEquivalent) !=
        FileSystemEntityType.notFound) {
      return TestFileMatch(exists: true, path: testEquivalent);
    }
  }
  return TestFileMatch(exists: false, path: '');
}
