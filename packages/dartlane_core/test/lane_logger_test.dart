import 'package:dartlane_core/dartlane_core.dart';
import 'package:mason_logger/mason_logger.dart' as mason;
import 'package:test/test.dart';

import 'support/recording_logger.dart';

void main() {
  late List<String> lines;

  setUp(() => lines = []);

  group('LaneLogger', () {
    test('verbose reflects the delegate level', () {
      expect(LaneLogger().verbose, isFalse);
      expect(LaneLogger(verbose: true).verbose, isTrue);
    });

    test('routes each level to the delegate', () {
      recordingLogger(lines)
        ..info('i')
        ..success('s')
        ..warn('w')
        ..error('e')
        ..detail('d');
      expect(lines, ['i', 's', 'warning: w', 'error: e']);
    });

    test('detail is printed when the delegate is verbose', () {
      LaneLogger(
        delegate: RecordingMasonLogger(lines, level: mason.Level.verbose),
      ).detail('d');
      expect(lines, ['d']);
    });
  });
}
