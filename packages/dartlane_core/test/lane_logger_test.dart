import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:test/test.dart';

void main() {
  group('LaneLogger', () {
    test('verbose reflects the delegate level', () {
      expect(LaneLogger().verbose, isFalse);
      expect(LaneLogger(verbose: true).verbose, isTrue);
    });

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
  });
}
