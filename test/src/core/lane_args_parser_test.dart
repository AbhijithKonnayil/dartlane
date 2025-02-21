import 'package:dartlane/src/core/lane_args_parser.dart';
import 'package:test/test.dart';

void main() {
  group('LaneArgsParser', () {
    test('parses key-value pairs correctly', () {
      final parser = LaneArgsParser(['key1:value1', 'key2:value2']);
      final result = parser.parse();

      expect(result, equals({'key1': 'value1', 'key2': 'value2'}));
    });

    test('trims values correctly', () {
      final parser = LaneArgsParser(['key1: value1 ', 'key2: value2 ']);
      final result = parser.parse();

      expect(result, equals({'key1': 'value1', 'key2': 'value2'}));
    });

    test('handles empty input', () {
      final parser = LaneArgsParser([]);
      final result = parser.parse();

      expect(result, isEmpty);
    });

    test('handles invalid input gracefully', () {
      final parser = LaneArgsParser(['invalid']);
      final result = parser.parse();

      expect(result, isEmpty);
    });

    test('handles mixed valid and invalid input', () {
      final parser = LaneArgsParser(['key1:value1', 'invalid', 'key2:value2']);
      final result = parser.parse();

      expect(result, equals({'key1': 'value1', 'key2': 'value2'}));
    });
  });
}
