class TestFileMatch {
  final bool exists;
  final String path;
  final bool integrationTest;

  TestFileMatch({
    required this.exists,
    required this.path,
    this.integrationTest = false,
  });

  @override
  String toString() {
    return 'path: $path\nexists: $exists\nintegrationTest: $integrationTest';
  }

  @override
  bool operator ==(Object other) {
    if (other is TestFileMatch) {
      return exists == other.exists &&
          path == other.path &&
          integrationTest == other.integrationTest;
    }
    return false;
  }

  @override
  int get hashCode => 'TestFileMatch:$exists,$path,$integrationTest'.hashCode;
}
