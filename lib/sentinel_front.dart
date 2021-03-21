import 'package:args/args.dart';
import 'package:equatable/equatable.dart';

enum Command {
  help,
  watch,
}

class ParseResult with EquatableMixin {
  final Command command;
  final bool integration;
  final String device;
  final String directory;

  ParseResult(
    this.command, {
    required this.integration,
    this.device = 'all',
    this.directory = '',
  });

  static final help = ParseResult(
    Command.help,
    integration: false,
  );
  factory ParseResult.watch({
    bool integration = false,
    String device = 'all',
    String directory = '',
  }) {
    return ParseResult(
      Command.watch,
      integration: integration,
      device: device,
      directory: directory,
    );
  }

  @override
  List<Object?> get props => [command, integration, device, directory];
}

class SentinelFront {
  final ArgParser _parser;

  factory SentinelFront() => SentinelFront._(ArgParser());

  SentinelFront._(this._parser) {
    _parser.addFlag(
      'integration',
      negatable: false,
      abbr: 'i',
      help: 'Include integration tests in test runs.',
    );
    _parser.addOption(
      'device',
      abbr: 'd',
      defaultsTo: 'all',
      help: 'Specify the device to run integration tests against.',
    );
    _parser.addFlag(
      'help',
      negatable: false,
      abbr: 'h',
      help: 'Display usage information.',
    );
  }

  ParseResult parse(List<String> arguments) {
    final args = _parser.parse(arguments);
    if (args['help'] as bool) {
      return ParseResult.help;
    }

    final pathArgs = args.rest;
    return ParseResult(
      Command.watch,
      integration: args['integration'] as bool,
      device: args['device'] as String,
      directory: pathArgs.isNotEmpty ? pathArgs.first : '',
    );
  }

  String helpText() {
    return '''
A Dart and Flutter project automated test runner.

Usage: sentinel [<flags>] <directory>

${_parser.usage}

See https://pub.dev/packages/sentinel for more information.
''';
  }
}
