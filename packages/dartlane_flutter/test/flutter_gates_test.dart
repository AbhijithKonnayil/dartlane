import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:dartlane_flutter/dartlane_flutter.dart';
import 'package:test/test.dart';

void main() {
  late FakeLaneContext ctx;

  setUp(() => ctx = FakeLaneContext());

  test('FlutterPubGet runs pub get', () async {
    await ctx.run<void>(const FlutterPubGet());
    expect(ctx.shell.commands, ['flutter pub get']);
  });

  test('FlutterPubGet offline', () async {
    await ctx.run<void>(const FlutterPubGet(offline: true));
    expect(ctx.shell.commands, ['flutter pub get --offline']);
  });

  test('FlutterAnalyze defaults to fatal infos and warnings', () async {
    await ctx.run<void>(const FlutterAnalyze());
    expect(ctx.shell.commands, ['flutter analyze']);
  });

  test('FlutterAnalyze can relax infos and warnings', () async {
    await ctx.run<void>(
      const FlutterAnalyze(fatalInfos: false, fatalWarnings: false),
    );
    expect(ctx.shell.commands, [
      'flutter analyze --no-fatal-infos --no-fatal-warnings',
    ]);
  });

  test('FlutterTest passes coverage and paths', () async {
    await ctx.run<void>(
      const FlutterTest(coverage: true, paths: ['test/a_test.dart']),
    );
    expect(ctx.shell.commands, ['flutter test --coverage test/a_test.dart']);
  });

  test('a failing analyze fails the lane', () {
    ctx.shell.stub('flutter analyze', exitCode: 1, stderr: '1 issue found.');
    expect(
      ctx.run<void>(const FlutterAnalyze()),
      throwsA(isA<ShellException>()),
    );
  });

  test('a failing test fails the lane', () {
    ctx.shell.stub('flutter test', exitCode: 1);
    expect(ctx.run<void>(const FlutterTest()), throwsA(isA<ShellException>()));
  });

  test('dry run describes without running', () async {
    final dry = FakeLaneContext(dryRun: true);
    await dry.run<void>(const FlutterPubGet());
    await dry.run<void>(const FlutterAnalyze());
    await dry.run<void>(const FlutterTest());
    expect(dry.shell.commands, isEmpty);
    expect(dry.dryRunSteps, [
      'flutter pub get',
      'flutter analyze',
      'flutter test',
    ]);
  });
}
