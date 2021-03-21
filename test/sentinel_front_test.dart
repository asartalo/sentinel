import 'package:sentinel/sentinel_front.dart';
import 'package:test/test.dart';

class T {
  final List<String> args;
  final ParseResult result;

  T(this.args, this.result);
}

void main() {
  group('SentinelFront', () {
    final front = SentinelFront();

    final Map<String, T> testData = {
      'basic help': T(['--help'], ParseResult.help),
      'default': T(
        [],
        ParseResult.watch(
          // ignore: avoid_redundant_argument_values
          integration: false,
          // ignore: avoid_redundant_argument_values
          device: 'all',
        ),
      ),
      'with integration': T(
        ['-i'],
        ParseResult.watch(integration: true),
      ),
      'with integration and device': T(
        ['--integration', '-d', 'chrome'],
        ParseResult.watch(
          integration: true,
          device: 'chrome',
        ),
      ),
      'with directory specified': T(
        ['/some/directory'],
        ParseResult.watch(
          directory: '/some/directory',
        ),
      ),
    };

    testData.forEach((description, data) {
      test(description, () {
        final result = front.parse(data.args);
        expect(result, data.result);
      });
    });
  });
}
