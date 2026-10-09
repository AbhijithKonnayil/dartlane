import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_flutter/src/actions/flutter_build.dart';
import 'package:dartlane_flutter/src/actions/flutter_gates.dart';

/// Ready-made lanes for the Flutter actions, to spread into the `lanes` map.
///
/// ```dart
/// dartlane(args, lanes: {...flutterLanes(), 'beta': Lane(...)});
/// ```
///
/// | Lane | Runs |
/// | --- | --- |
/// | `flutter_build_apk` | `FlutterBuild.apk` |
/// | `flutter_build_appbundle` | `FlutterBuild.appBundle` |
/// | `flutter_pub_get` | `FlutterPubGet` |
/// | `flutter_analyze` | `FlutterAnalyze` |
/// | `flutter_test` | `FlutterTest` |
///
/// These replace the old `flutterBuildApk` and `flutterBuildAppBundle` lanes.
///
/// The build lanes take `--mode=debug|profile|release`, `--flavor`,
/// `--dart-define=KEY=VALUE` (repeatable), `--build-name`, `--build-number`,
/// `--obfuscate` and `--split-debug-info`. Unknown options are an error.
Map<String, Lane> flutterLanes() => {
  'flutter_build_apk': Lane(
    'Build an APK (--mode, --flavor, --dart-define, --build-name, ...)',
    (ctx) => _build(ctx, BuildTarget.apk),
  ),
  'flutter_build_appbundle': Lane(
    'Build an app bundle (--mode, --flavor, --dart-define, ...)',
    (ctx) => _build(ctx, BuildTarget.appbundle),
  ),
  'flutter_pub_get': Lane('Run flutter pub get (--offline)', (ctx) async {
    ctx.args.expectOnly(['offline']);
    await ctx.run(FlutterPubGet(offline: ctx.args.flag('offline')));
  }),
  'flutter_analyze': Lane(
    'Run flutter analyze (--no-fatal-infos, --no-fatal-warnings)',
    (ctx) async {
      ctx.args.expectOnly(['fatal-infos', 'fatal-warnings']);
      await ctx.run(
        FlutterAnalyze(
          fatalInfos: ctx.args.flag('fatal-infos', defaultValue: true),
          fatalWarnings: ctx.args.flag('fatal-warnings', defaultValue: true),
        ),
      );
    },
  ),
  'flutter_test': Lane(
    'Run flutter test (--coverage, test paths as arguments)',
    (ctx) async {
      ctx.args.expectOnly(['coverage']);
      await ctx.run(
        FlutterTest(
          paths: ctx.args.positional,
          coverage: ctx.args.flag('coverage'),
        ),
      );
    },
  ),
};

const _buildOptions = [
  'mode',
  'flavor',
  'dart-define',
  'build-name',
  'build-number',
  'obfuscate',
  'split-debug-info',
];

Future<void> _build(LaneContext ctx, BuildTarget target) async {
  final args = ctx.args..expectOnly(_buildOptions);
  final build = await ctx.run(
    FlutterBuild(
      target: target,
      mode: _mode(args.string('mode')),
      flavor: args.string('flavor'),
      dartDefines: args.list('dart-define', commaSeparated: false),
      buildName: args.string('build-name'),
      buildNumber: args.string('build-number'),
      obfuscate: args.flag('obfuscate'),
      splitDebugInfo: args.string('split-debug-info'),
    ),
  );
  ctx.logger.success('${ctx.dryRun ? 'Would build' : 'Built'} ${build.path}');
}

BuildMode _mode(String? name) {
  if (name == null) return BuildMode.release;
  for (final mode in BuildMode.values) {
    if (mode.name == name) return mode;
  }
  throw UserError(
    '--mode must be debug, profile or release, but got "$name".',
    hint: 'For example --mode=release.',
  );
}
