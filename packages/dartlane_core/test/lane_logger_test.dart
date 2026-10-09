import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:test/test.dart';

void main() {
  group('levels', () {
    test('routes each level to the delegate', () {
      final logger = FakeLaneLogger()
        ..info('i')
        ..success('s')
        ..warn('w')
        ..error('e')
        ..detail('d');
      expect(logger.lines, ['i', 's', 'warning: w', 'error: e']);
    });

    test('detail is recorded when verbose', () {
      final logger = FakeLaneLogger(verbose: true)..detail('d');
      expect(logger.lines, ['d']);
    });

    test('verbose can be switched on and off', () {
      final logger = FakeLaneLogger();
      expect(logger.verbose, isFalse);

      logger
        ..verbose = true
        ..detail('shown');
      expect(logger.verbose, isTrue);

      logger
        ..verbose = false
        ..detail('hidden');
      expect(logger.lines, ['shown']);
    });

    test('verbose reflects the constructor flag', () {
      expect(LaneLogger().verbose, isFalse);
      expect(LaneLogger(verbose: true).verbose, isTrue);
    });
  });

  group('GitHub Actions annotations', () {
    test('errors and warnings become annotations', () {
      final logger = FakeLaneLogger(githubActions: true)
        ..error('build failed')
        ..warn('slow network');
      expect(logger.lines, [
        '::error::build failed',
        '::warning::slow network',
      ]);
    });

    test('other levels are printed as usual', () {
      final logger = FakeLaneLogger(githubActions: true, verbose: true)
        ..info('i')
        ..success('s')
        ..detail('d');
      expect(logger.lines, ['i', 's', 'd']);
    });

    test('newlines and percent signs are escaped', () {
      final logger = FakeLaneLogger(githubActions: true)
        ..error('line one\nline two\r100%');
      expect(logger.lines, ['::error::line one%0Aline two%0D100%25']);
    });

    test('are off by default', () {
      final logger = FakeLaneLogger()..error('e');
      expect(logger.lines, ['error: e']);
    });
  });

  group('LaneLogger.fromEnvironment', () {
    test('GITHUB_ACTIONS turns on annotations and turns off prompts', () {
      final logger = LaneLogger.fromEnvironment({'GITHUB_ACTIONS': 'true'});
      expect(logger.githubActions, isTrue);
      expect(logger.interactive, isFalse);
    });

    test('CI turns off prompts but not annotations', () {
      final logger = LaneLogger.fromEnvironment({'CI': 'true'});
      expect(logger.githubActions, isFalse);
      expect(logger.interactive, isFalse);
    });

    test('an empty environment is not GitHub Actions', () {
      expect(LaneLogger.fromEnvironment({}).githubActions, isFalse);
    });

    test('verbose is passed on', () {
      expect(LaneLogger.fromEnvironment({}, verbose: true).verbose, isTrue);
    });
  });

  group('confirm', () {
    test('does not ask when not interactive and returns the default', () {
      final logger = FakeLaneLogger(confirmAnswer: false);

      expect(logger.confirm('Overwrite?', defaultValue: true), isTrue);
      expect(logger.confirm('Overwrite?'), isFalse);
      expect(logger.lines, isEmpty);
    });

    test('asks when interactive and returns the answer', () {
      final logger = FakeLaneLogger(interactive: true, confirmAnswer: false);

      expect(logger.confirm('Overwrite?', defaultValue: true), isFalse);
      expect(logger.lines, ['confirm: Overwrite?']);
    });
  });
}
