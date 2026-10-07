import 'package:dartlane_core/dartlane_core.dart';
import 'package:test/test.dart';

import 'support/recording_logger.dart';
import 'support/sample_actions.dart';

void main() {
  late List<String> lines;
  late LaneContext ctx;

  setUp(() {
    lines = [];
    ctx = LaneContext(logger: recordingLogger(lines));
  });

  group('LaneContext.run', () {
    test('returns the action result', () async {
      expect(await ctx.run(const UppercaseAction('hi')), 'HI');
    });

    test('logs the step with timing', () async {
      await ctx.run(const UppercaseAction('hi'));
      expect(lines.first, '> uppercase hi');
      expect(lines.last, matches(RegExp(r'^  done \(\d+ms\)$')));
    });

    test('describe defaults to the class name', () async {
      await ctx.run(const DefaultDescribeAction());
      expect(lines.first, '> DefaultDescribeAction');
    });

    test('logs a failure and rethrows it', () async {
      await expectLater(ctx.run(const FailingAction()), throwsStateError);
      expect(
        lines.last,
        matches(RegExp(r'^error: FailingAction failed \(\d+ms\)$')),
      );
    });
  });
}
