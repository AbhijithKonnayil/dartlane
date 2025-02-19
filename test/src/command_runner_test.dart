import 'package:dartlane/src/command_runner.dart';
import 'package:dartlane/src/commands/update_command.dart';
import 'package:dartlane/src/core/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';

class MockDLogger extends Mock implements DLogger {}

class MockPubUpdater extends Mock implements PubUpdater {}

void main() {
  group('DartlaneCommandRunner', () {
    late MockDLogger mockLogger;
    late MockPubUpdater mockPubUpdater;
    late DartlaneCommandRunner commandRunner;

    setUp(() {
      mockLogger = MockDLogger();
      mockPubUpdater = MockPubUpdater();
      commandRunner = DartlaneCommandRunner(
        logger: mockLogger,
        pubUpdater: mockPubUpdater,
      );
    });

    test('should have correct executable name and description', () {
      expect(commandRunner.executableName, 'dartlane');
      expect(commandRunner.description,
          'A Very Good Project created by Very Good CLI.');
    });

    test('should add version flag', () {
      final argResults = commandRunner.argParser.parse(['--version']);
      expect(argResults['version'], isTrue);
    });

    test('should add verbose flag', () {
      final argResults = commandRunner.argParser.parse(['--verbose']);
      expect(argResults['verbose'], isTrue);
    });

    test('should add UpdateCommand', () {
      final commands = commandRunner.commands;
      expect(commands.containsKey('update'), isTrue);
      expect(commands['update'], isA<UpdateCommand>());
    });
  });
}
