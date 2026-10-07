import 'package:dartlane_core/dartlane_core.dart';
import 'package:test/test.dart';

void main() {
  group('LaneError', () {
    test('a user error maps to the usage exit code', () {
      expect(const UserError('bad value').exitCode, ExitCodes.usage);
    });

    test('an action failure maps to the failure exit code', () {
      expect(const ActionFailed('boom').exitCode, ExitCodes.failure);
    });

    test('toString is the message only', () {
      expect('${const UserError('bad value', hint: 'fix it')}', 'bad value');
      expect('${const ActionFailed('boom')}', 'boom');
    });

    test('a user error carries an optional hint', () {
      expect(const UserError('x').hint, isNull);
      expect(const UserError('x', hint: 'y').hint, 'y');
    });

    test('a failed command is an action failure', () {
      final error = ShellException(
        commandLine: 'flutter build apk',
        result: const ShellResult(exitCode: 1),
      );
      expect(error, isA<ActionFailed>());
      expect(error.exitCode, ExitCodes.failure);
    });
  });
}
