import 'package:dartlane_core/dartlane_core.dart';
import 'package:test/test.dart';

import 'support/recording_logger.dart';
import 'support/sample_actions.dart';

void main() {
  late List<String> lines;
  late LaneLogger logger;

  setUp(() {
    lines = [];
    logger = recordingLogger(lines);
  });

  group('runLanes', () {
    test('runs a plain function lane that calls actions', () async {
      String? result;
      final code = await runLanes(
        ['beta'],
        lanes: {
          'beta': Lane('Beta', (ctx) async {
            result = await ctx.run(const UppercaseAction('x'));
          }),
        },
        logger: logger,
      );
      expect(code, ExitCodes.success);
      expect(result, 'X');
    });

    test('accepts a synchronous lane body', () async {
      var ran = false;
      final code = await runLanes(
        ['sync'],
        lanes: {'sync': Lane('Sync', (ctx) => ran = true)},
        logger: logger,
      );
      expect(code, ExitCodes.success);
      expect(ran, isTrue);
    });

    test('passes remaining args and env to the lane', () async {
      LaneContext? seen;
      await runLanes(
        ['beta', '--flavor=prod', 'x'],
        lanes: {'beta': Lane('Beta', (ctx) => seen = ctx)},
        env: {'A': '1'},
        logger: logger,
      );
      expect(seen!.args, ['--flavor=prod', 'x']);
      expect(seen!.env, {'A': '1'});
    });

    test('unknown lane lists the available lanes and fails', () async {
      final code = await runLanes(
        ['nope'],
        lanes: {
          'beta': Lane('Ship to QA', (ctx) {}),
          'alpha': Lane('Ship to devs', (ctx) {}),
        },
        logger: logger,
      );
      expect(code, ExitCodes.usage);
      expect(lines, contains('error: Unknown lane "nope".'));
      expect(lines, contains('Available lanes:'));
      expect(lines, contains('  beta   Ship to QA'));
      expect(lines, contains('  alpha  Ship to devs'));
    });

    test('missing lane name lists the available lanes and fails', () async {
      final code = await runLanes(
        [],
        lanes: {'beta': Lane('Ship to QA', (ctx) {})},
        logger: logger,
      );
      expect(code, ExitCodes.usage);
      expect(lines, contains('error: No lane given.'));
      expect(lines, contains('  beta  Ship to QA'));
    });

    test('a failing lane exits non-zero', () async {
      final code = await runLanes(
        ['bad'],
        lanes: {'bad': Lane('Bad', (ctx) => ctx.run(const FailingAction()))},
        logger: logger,
      );
      expect(code, ExitCodes.failure);
      expect(lines.any((l) => l.contains('Lane "bad" failed')), isTrue);
    });
  });
}
