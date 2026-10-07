import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:dartlane_flutter/dartlane_flutter.dart';
import 'package:test/test.dart';

const _apkOutput = '''
Running Gradle task 'assembleRelease'...                           41.2s
✓ Built build/app/outputs/flutter-apk/app-release.apk (20.1MB)
''';

void main() {
  late FakeLaneContext ctx;

  setUp(() => ctx = FakeLaneContext());

  group('arguments', () {
    test('builds a release apk by default', () async {
      ctx.shell.stub('flutter build apk --release', stdout: _apkOutput);

      await ctx.run(const FlutterBuild(target: BuildTarget.apk));

      expect(ctx.shell.commands, ['flutter build apk --release']);
    });

    test('builds an app bundle in another mode', () async {
      ctx.shell.stub(
        'flutter build appbundle --profile',
        stdout: 'Built build/app/outputs/bundle/profile/app-profile.aab',
      );

      await ctx.run(
        const FlutterBuild(
          target: BuildTarget.appbundle,
          mode: BuildMode.profile,
        ),
      );

      expect(ctx.shell.commands, ['flutter build appbundle --profile']);
    });

    test('passes every option', () async {
      const build = FlutterBuild(
        target: BuildTarget.apk,
        flavor: 'prod',
        dartDefines: ['ENV=prod'],
        buildName: '1.2.3',
        buildNumber: '45',
        obfuscate: true,
        splitDebugInfo: 'build/debug-info',
      );
      ctx.shell.stub(build.describe(), stdout: _apkOutput);

      await ctx.run(build);

      expect(ctx.shell.calls.single.arguments, [
        'build',
        'apk',
        '--release',
        '--flavor=prod',
        '--dart-define=ENV=prod',
        '--build-name=1.2.3',
        '--build-number=45',
        '--obfuscate',
        '--split-debug-info=build/debug-info',
      ]);
    });

    test('passes --dart-define once per entry', () async {
      const build = FlutterBuild(
        target: BuildTarget.apk,
        dartDefines: ['A=1', 'B=two words', 'C=x=y'],
      );
      ctx.shell.stub(build.describe(), stdout: _apkOutput);

      await ctx.run(build);

      expect(ctx.shell.calls.single.arguments, [
        'build',
        'apk',
        '--release',
        '--dart-define=A=1',
        '--dart-define=B=two words',
        '--dart-define=C=x=y',
      ]);
    });

    test('runs in the working directory', () async {
      const build = FlutterBuild(
        target: BuildTarget.apk,
        workingDirectory: 'app',
      );
      ctx.shell.stub(build.describe(), stdout: _apkOutput);

      await ctx.run(build);

      expect(ctx.shell.calls.single.workingDirectory, 'app');
    });

    test('describes itself as the command', () {
      expect(
        const FlutterBuild(target: BuildTarget.apk, flavor: 'prod').describe(),
        'flutter build apk --release --flavor=prod',
      );
    });

    test('is logged as a step', () async {
      ctx.shell.stub('flutter build apk --release', stdout: _apkOutput);

      await ctx.run(const FlutterBuild(target: BuildTarget.apk));

      expect(ctx.logger.lines.first, '> flutter build apk --release');
    });
  });

  group('result', () {
    test('path is the one Flutter reports', () async {
      ctx.shell.stub('flutter build apk --release', stdout: _apkOutput);

      final result = await ctx.run(const FlutterBuild(target: BuildTarget.apk));

      expect(result.path, 'build/app/outputs/flutter-apk/app-release.apk');
      expect(result.target, BuildTarget.apk);
      expect(result.mode, BuildMode.release);
      expect(result.flavor, isNull);
      expect(result.version, isNull);
    });

    test('path points at the flavored artifact', () async {
      const build = FlutterBuild(target: BuildTarget.apk, flavor: 'prod');
      ctx.shell.stub(
        build.describe(),
        stdout:
            '✓ Built build/app/outputs/flutter-apk/app-prod-release.apk '
            '(20.1MB)',
      );

      final result = await ctx.run(build);

      expect(
        result.path,
        'build/app/outputs/flutter-apk/app-prod-release.apk',
      );
      expect(result.flavor, 'prod');
    });

    test('path is the flavored app bundle', () async {
      const build = FlutterBuild(target: BuildTarget.appbundle, flavor: 'prod');
      const aab = 'build/app/outputs/bundle/prodRelease/app-prod-release.aab';
      ctx.shell.stub(build.describe(), stdout: '✓ Built $aab (30.0MB)');

      final result = await ctx.run(build);

      expect(result.path, aab);
    });

    test(
      'path is relative to the working directory when one is given',
      () async {
        const build = FlutterBuild(
          target: BuildTarget.apk,
          workingDirectory: 'app',
        );
        ctx.shell.stub(build.describe(), stdout: _apkOutput);

        final result = await ctx.run(build);

        expect(
          result.path,
          'app/build/app/outputs/flutter-apk/app-release.apk',
        );
      },
    );

    test('version combines the build name and number', () async {
      const both = FlutterBuild(
        target: BuildTarget.apk,
        buildName: '1.2.3',
        buildNumber: '45',
      );
      ctx.shell.stub(both.describe(), stdout: _apkOutput);
      expect((await ctx.run(both)).version, '1.2.3+45');

      const nameOnly = FlutterBuild(
        target: BuildTarget.apk,
        buildName: '1.2.3',
      );
      ctx.shell.stub(nameOnly.describe(), stdout: _apkOutput);
      expect((await ctx.run(nameOnly)).version, '1.2.3');
    });
  });

  group('failures', () {
    test('a failed build fails the lane', () async {
      ctx.shell.stub(
        'flutter build apk --release',
        exitCode: 1,
        stderr: 'Gradle task assembleRelease failed',
      );

      await expectLater(
        ctx.run(const FlutterBuild(target: BuildTarget.apk)),
        throwsA(
          isA<ShellException>()
              .having((e) => e.result.exitCode, 'exitCode', 1)
              .having((e) => '$e', 'message', contains('assembleRelease')),
        ),
      );
    });

    test(
      'a failed build gives a non-zero exit code through the runner',
      () async {
        final logger = FakeLaneLogger();
        final lane = Lane('Build', (ctx) => ctx.run(const _AlwaysFails()));

        final code = await runLanes(
          ['go'],
          lanes: {'go': lane},
          logger: logger,
        );

        expect(code, ExitCodes.failure);
      },
    );

    test('a build that reports no file is an error, not a guess', () async {
      ctx.shell.stub('flutter build apk --release', stdout: 'Done.');

      await expectLater(
        ctx.run(const FlutterBuild(target: BuildTarget.apk)),
        throwsA(isA<ActionFailed>()),
      );
    });

    test('a dart define without = is a user error', () async {
      await expectLater(
        ctx.run(
          const FlutterBuild(target: BuildTarget.apk, dartDefines: ['ENV']),
        ),
        throwsA(
          isA<UserError>().having((e) => e.message, 'message', contains('ENV')),
        ),
      );
      expect(ctx.shell.commands, isEmpty);
    });

    test('obfuscate without splitDebugInfo is a user error', () async {
      await expectLater(
        ctx.run(const FlutterBuild(target: BuildTarget.apk, obfuscate: true)),
        throwsA(isA<UserError>()),
      );
      expect(ctx.shell.commands, isEmpty);
    });
  });

  group('named constructors', () {
    test('FlutterBuild.apk builds an apk', () {
      const build = FlutterBuild.apk(flavor: 'prod', mode: BuildMode.debug);

      expect(build.target, BuildTarget.apk);
      expect(build.describe(), 'flutter build apk --debug --flavor=prod');
    });

    test('FlutterBuild.appBundle builds an app bundle', () {
      const build = FlutterBuild.appBundle(dartDefines: ['A=1']);

      expect(build.target, BuildTarget.appbundle);
      expect(
        build.describe(),
        'flutter build appbundle --release --dart-define=A=1',
      );
    });

    test('they take every option', () {
      const build = FlutterBuild.apk(
        flavor: 'f',
        dartDefines: ['A=1'],
        buildName: '1.0.0',
        buildNumber: '2',
        obfuscate: true,
        splitDebugInfo: 'd',
        workingDirectory: 'app',
      );

      expect(build.flavor, 'f');
      expect(build.dartDefines, ['A=1']);
      expect(build.buildName, '1.0.0');
      expect(build.buildNumber, '2');
      expect(build.obfuscate, isTrue);
      expect(build.splitDebugInfo, 'd');
      expect(build.workingDirectory, 'app');
    });
  });
}

/// A build whose command fails, run through the real runner.
class _AlwaysFails extends LaneAction<void> {
  const _AlwaysFails();

  @override
  Future<void> run(LaneContext ctx) => ctx.sh('dart', ['--no-such-flag']);
}
